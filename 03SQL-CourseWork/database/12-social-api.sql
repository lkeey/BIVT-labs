/*
 * Social write API for a trusted backend. Apply after tables, access views and
 * outbox procedures. The owner is Community.OwnerUserID; an OWNER edge is
 * not required. Callers must not have direct DML rights on these tables.
 *
 * Membership changes and publication share the same per-community applock.
 * Legacy BANNED/REJECTED/LEFT rows remain valid for historical data.
 */
IF EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'social.MemberOf')
      AND name = N'CK_MemberOf_Status'
      AND definition NOT LIKE N'%''BLOCKED''%'
)
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        ALTER TABLE social.MemberOf DROP CONSTRAINT CK_MemberOf_Status;
        ALTER TABLE social.MemberOf WITH CHECK ADD CONSTRAINT CK_MemberOf_Status
            CHECK (MemberStatus IN ('PENDING','ACTIVE','BLOCKED','REJECTED','BANNED','LEFT'));
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'social.MemberOf')
      AND name = N'CK_MemberOf_Status'
)
    ALTER TABLE social.MemberOf WITH CHECK ADD CONSTRAINT CK_MemberOf_Status
        CHECK (MemberStatus IN ('PENDING','ACTIVE','BLOCKED','REJECTED','BANNED','LEFT'));
GO
IF EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'social.MemberOf')
      AND name = N'CK_MemberOf_Role'
      AND definition NOT LIKE N'%''ADMIN''%'
)
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        ALTER TABLE social.MemberOf DROP CONSTRAINT CK_MemberOf_Role;
        ALTER TABLE social.MemberOf WITH CHECK ADD CONSTRAINT CK_MemberOf_Role
            CHECK ([Role] IN ('OWNER','ADMIN','MODERATOR','MEMBER'));
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'social.MemberOf')
      AND name = N'CK_MemberOf_Role'
)
    ALTER TABLE social.MemberOf WITH CHECK ADD CONSTRAINT CK_MemberOf_Role
        CHECK ([Role] IN ('OWNER','ADMIN','MODERATOR','MEMBER'));
GO

/* The unique slug is the natural retry key; ownership is canonical here. */
CREATE OR ALTER PROCEDURE social.usp_CreateCommunity
    @OwnerUserID bigint,
    @Slug nvarchar(100),
    @Name nvarchar(160),
    @Visibility varchar(8),
    @Description nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Slug IS NULL OR LEN(@Slug) NOT BETWEEN 3 AND 100
       OR DATALENGTH(@Slug) <> DATALENGTH(LTRIM(RTRIM(@Slug)))
       OR @Slug COLLATE Latin1_General_100_BIN2 LIKE N'%[^a-z0-9-]%'
        THROW 51178, N'Slug must contain 3-100 lower-case ASCII letters, digits or hyphens.', 1;
    IF NULLIF(LTRIM(RTRIM(@Name)),N'') IS NULL
        THROW 51179, N'Community name is required.', 1;
    IF @Visibility IS NULL OR @Visibility NOT IN ('PUBLIC','PRIVATE')
        THROW 51180, N'Visibility must be PUBLIC or PRIVATE.', 1;
    DECLARE @CommunityID bigint, @Created bit=0,
            @ExistingOwnerUserID bigint,
            @ExistingName nvarchar(160), @ExistingVisibility varchar(8),
            @ExistingDescription nvarchar(1000), @ExistingStatus varchar(12),
            @LockResult int,
            @LockResource nvarchar(255);
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @LockResource = CONCAT(N'social:community:slug:', @Slug);
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51181, N'Could not lock community slug.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount
                       WHERE UserID = @OwnerUserID AND AccountStatus = 'ACTIVE')
            THROW 51152, N'Active owner not found.', 1;
        SELECT @CommunityID = CommunityID, @ExistingOwnerUserID = OwnerUserID,
               @ExistingName = CommunityName, @ExistingVisibility = Visibility,
               @ExistingDescription = Description, @ExistingStatus = Status
        FROM social.Community WITH (UPDLOCK,HOLDLOCK)
        WHERE Slug = @Slug;
        IF @CommunityID IS NULL
        BEGIN
            INSERT INTO social.Community
                (OwnerUserID,Slug,CommunityName,Description,Visibility)
            VALUES (@OwnerUserID,@Slug,@Name,@Description,@Visibility);
            SET @CommunityID = CONVERT(bigint,SCOPE_IDENTITY());
            SET @Created = 1;
            INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
            VALUES (@OwnerUserID,'COMMUNITY_CREATE','COMMUNITY',@CommunityID);
        END
        ELSE IF @ExistingStatus <> 'ACTIVE'
             OR @ExistingOwnerUserID <> @OwnerUserID OR @ExistingName <> @Name
             OR @ExistingVisibility <> @Visibility
             OR ISNULL(@ExistingDescription,N'') <> ISNULL(@Description,N'')
            THROW 51182, N'Slug already belongs to a different community definition.', 1;
        COMMIT TRANSACTION;
        SELECT @CommunityID AS CommunityID,@Created AS Created;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Public membership starts ACTIVE; a private community creates a PENDING request. */
CREATE OR ALTER PROCEDURE social.usp_RequestMembership
    @UserID bigint,
    @CommunityID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @LockResult int, @LockResource nvarchar(255),
            @OwnerUserID bigint, @Visibility varchar(8),
            @MembershipID bigint, @CurrentStatus varchar(8), @CurrentRole varchar(10),
            @CurrentCount bigint, @ResultStatus varchar(8), @ResultRole varchar(10),
            @Created bit=0;

    BEGIN TRY
        BEGIN TRANSACTION;
        SET @LockResource = CONCAT(N'social:community:', @CommunityID, N':membership');
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51150, N'Could not lock community membership.', 1;

        SELECT @OwnerUserID = OwnerUserID, @Visibility = Visibility
        FROM social.Community WITH (HOLDLOCK)
        WHERE CommunityID = @CommunityID AND Status = 'ACTIVE';
        IF @OwnerUserID IS NULL
            THROW 51151, N'Active community not found.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount
                       WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
            THROW 51152, N'Active user not found.', 1;

        IF @UserID = @OwnerUserID
        BEGIN
            SET @ResultStatus = 'ACTIVE';
            SET @ResultRole = 'OWNER';
        END
        ELSE
        BEGIN
            SELECT @CurrentCount = COUNT_BIG(*)
            FROM auth.UserAccount AS member,
                 social.MemberOf AS edge,
                 social.Community AS community
            WHERE MATCH(member-(edge)->community)
              AND member.UserID = @UserID AND community.CommunityID = @CommunityID
              AND edge.EndedAt IS NULL;
            IF @CurrentCount > 1
                THROW 51153, N'Multiple current memberships require repair.', 1;
            SELECT @MembershipID = edge.MembershipID,
                   @CurrentStatus = edge.MemberStatus, @CurrentRole = edge.[Role]
            FROM auth.UserAccount AS member,
                 social.MemberOf AS edge,
                 social.Community AS community
            WHERE MATCH(member-(edge)->community)
              AND member.UserID = @UserID AND community.CommunityID = @CommunityID
              AND edge.EndedAt IS NULL;

            IF @CurrentStatus IN ('BLOCKED','BANNED')
                THROW 51154, N'Blocked users cannot request membership.', 1;
            IF @CurrentRole = 'OWNER'
                THROW 51183, N'An OWNER edge conflicts with the canonical owner.', 1;
            IF @CurrentStatus = 'PENDING' AND @Visibility = 'PUBLIC'
            BEGIN
                UPDATE social.MemberOf SET MemberStatus = 'ACTIVE'
                WHERE MembershipID = @MembershipID;
                SET @ResultStatus = 'ACTIVE';
                SET @ResultRole = @CurrentRole;
                INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
                VALUES (@UserID,'MEMBERSHIP_JOIN','MEMBERSHIP',@MembershipID);
            END
            ELSE IF @CurrentStatus IN ('ACTIVE','PENDING')
            BEGIN
                SET @ResultStatus = @CurrentStatus;
                SET @ResultRole = @CurrentRole;
            END
            ELSE
            BEGIN
                IF @MembershipID IS NOT NULL
                    UPDATE social.MemberOf SET EndedAt = SYSUTCDATETIME()
                    WHERE MembershipID = @MembershipID;
                SET @ResultStatus = CASE WHEN @Visibility = 'PUBLIC' THEN 'ACTIVE'
                                         ELSE 'PENDING' END;
                SET @ResultRole = 'MEMBER';
                INSERT INTO social.MemberOf ($from_id,$to_id,MemberStatus,[Role])
                SELECT member.$node_id, community.$node_id, @ResultStatus, @ResultRole
                FROM auth.UserAccount AS member, social.Community AS community
                WHERE member.UserID = @UserID AND community.CommunityID = @CommunityID;
                SET @MembershipID = CONVERT(bigint, SCOPE_IDENTITY());
                SET @Created = 1;
                INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
                VALUES (@UserID,'MEMBERSHIP_REQUEST','MEMBERSHIP',@MembershipID);
            END;
        END;
        COMMIT TRANSACTION;
        SELECT @MembershipID AS MembershipID, @ResultStatus AS MemberStatus,
               @ResultRole AS [Role], @Created AS Created;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* OWNER may appoint ADMIN; ADMIN may manage MEMBER and MODERATOR only. */
CREATE OR ALTER PROCEDURE social.usp_SetMembership
    @ActorUserID bigint,
    @CommunityID bigint,
    @TargetUserID bigint,
    @MemberStatus varchar(8),
    @Role varchar(10) = 'MEMBER'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @MemberStatus IS NULL OR @MemberStatus NOT IN ('PENDING','ACTIVE','BLOCKED')
        THROW 51155, N'Membership status must be PENDING, ACTIVE or BLOCKED.', 1;
    IF @Role IS NULL OR @Role NOT IN ('ADMIN','MODERATOR','MEMBER')
        THROW 51156, N'Role must be ADMIN, MODERATOR or MEMBER.', 1;
    IF @MemberStatus <> 'ACTIVE' AND @Role <> 'MEMBER'
        THROW 51157, N'Non-active membership cannot have an elevated role.', 1;

    DECLARE @LockResult int, @LockResource nvarchar(255),
            @OwnerUserID bigint, @ActorRole varchar(10),
            @MembershipID bigint, @CurrentStatus varchar(8), @CurrentRole varchar(10),
            @CurrentCount bigint, @Changed bit = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @LockResource = CONCAT(N'social:community:', @CommunityID, N':membership');
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51150, N'Could not lock community membership.', 1;

        SELECT @OwnerUserID = OwnerUserID
        FROM social.Community WITH (HOLDLOCK)
        WHERE CommunityID = @CommunityID AND Status = 'ACTIVE';
        IF @OwnerUserID IS NULL
            THROW 51151, N'Active community not found.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount
                       WHERE UserID = @ActorUserID AND AccountStatus = 'ACTIVE')
            THROW 51158, N'Active actor not found.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount
                       WHERE UserID = @TargetUserID AND AccountStatus = 'ACTIVE')
            THROW 51152, N'Active target user not found.', 1;
        IF @TargetUserID = @OwnerUserID
            THROW 51159, N'The canonical owner cannot be changed by membership API.', 1;

        IF @ActorUserID = @OwnerUserID SET @ActorRole = 'OWNER';
        ELSE
            SELECT @ActorRole = edge.[Role]
            FROM auth.UserAccount AS actor,
                 social.MemberOf AS edge,
                 social.Community AS community
            WHERE MATCH(actor-(edge)->community)
              AND actor.UserID = @ActorUserID AND community.CommunityID = @CommunityID
              AND edge.MemberStatus = 'ACTIVE' AND edge.EndedAt IS NULL
              AND edge.[Role] = 'ADMIN';
        IF @ActorRole NOT IN ('OWNER','ADMIN') OR @ActorRole IS NULL
            THROW 51160, N'Only owner or admin may manage membership.', 1;
        IF @ActorRole = 'ADMIN' AND (@ActorUserID = @TargetUserID OR @Role = 'ADMIN')
            THROW 51161, N'Admin cannot change self or grant admin role.', 1;

        SELECT @CurrentCount = COUNT_BIG(*)
        FROM auth.UserAccount AS target,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(target-(edge)->community)
          AND target.UserID = @TargetUserID AND community.CommunityID = @CommunityID
          AND edge.EndedAt IS NULL;
        IF @CurrentCount > 1
            THROW 51153, N'Multiple current memberships require repair.', 1;
        SELECT @MembershipID = edge.MembershipID,
               @CurrentStatus = edge.MemberStatus, @CurrentRole = edge.[Role]
        FROM auth.UserAccount AS target,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(target-(edge)->community)
          AND target.UserID = @TargetUserID AND community.CommunityID = @CommunityID
          AND edge.EndedAt IS NULL;
        IF @ActorRole = 'ADMIN' AND @CurrentRole IN ('OWNER','ADMIN')
            THROW 51162, N'Admin cannot change owner or another admin.', 1;

        IF @MembershipID IS NULL
        BEGIN
            INSERT INTO social.MemberOf ($from_id,$to_id,MemberStatus,[Role])
            SELECT target.$node_id, community.$node_id, @MemberStatus, @Role
            FROM auth.UserAccount AS target, social.Community AS community
            WHERE target.UserID = @TargetUserID AND community.CommunityID = @CommunityID;
            SET @MembershipID = CONVERT(bigint, SCOPE_IDENTITY());
            SET @Changed = 1;
        END
        ELSE IF @CurrentStatus <> @MemberStatus OR @CurrentRole <> @Role
        BEGIN
            UPDATE social.MemberOf
            SET MemberStatus = @MemberStatus, [Role] = @Role
            WHERE MembershipID = @MembershipID;
            SET @Changed = 1;
        END;
        IF @Changed = 1
            INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
            VALUES (@ActorUserID,'MEMBERSHIP_SET','MEMBERSHIP',@MembershipID);
        COMMIT TRANSACTION;
        SELECT @MembershipID AS MembershipID, @MemberStatus AS MemberStatus,
               @Role AS [Role];
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Leaving ends the current edge; a block survives a user's leave request. */
CREATE OR ALTER PROCEDURE social.usp_LeaveCommunity
    @UserID bigint,
    @CommunityID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @LockResult int, @LockResource nvarchar(255),
            @OwnerUserID bigint, @MembershipID bigint,
            @CurrentStatus varchar(8), @CurrentCount bigint;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @LockResource = CONCAT(N'social:community:', @CommunityID, N':membership');
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51150, N'Could not lock community membership.', 1;
        SELECT @OwnerUserID = OwnerUserID
        FROM social.Community WITH (HOLDLOCK) WHERE CommunityID = @CommunityID;
        IF @OwnerUserID IS NULL THROW 51163, N'Community not found.', 1;
        IF @UserID = @OwnerUserID
            THROW 51164, N'Owner cannot leave without transferring ownership.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE UserID = @UserID)
            THROW 51165, N'User not found.', 1;
        SELECT @CurrentCount = COUNT_BIG(*)
        FROM auth.UserAccount AS member,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(member-(edge)->community)
          AND member.UserID = @UserID AND community.CommunityID = @CommunityID
          AND edge.EndedAt IS NULL;
        IF @CurrentCount > 1
            THROW 51153, N'Multiple current memberships require repair.', 1;
        SELECT @MembershipID = edge.MembershipID, @CurrentStatus = edge.MemberStatus
        FROM auth.UserAccount AS member,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(member-(edge)->community)
          AND member.UserID = @UserID AND community.CommunityID = @CommunityID
          AND edge.EndedAt IS NULL;
        IF @CurrentStatus IN ('BLOCKED','BANNED')
            THROW 51166, N'Blocked membership cannot be removed by the member.', 1;
        IF @CurrentStatus IN ('ACTIVE','PENDING')
        BEGIN
            UPDATE social.MemberOf
            SET MemberStatus = 'LEFT', [Role] = 'MEMBER', EndedAt = SYSUTCDATETIME()
            WHERE MembershipID = @MembershipID;
            INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
            VALUES (@UserID,'MEMBERSHIP_LEFT','MEMBERSHIP',@MembershipID);
        END;
        COMMIT TRANSACTION;
        SELECT @MembershipID AS MembershipID, CAST('LEFT' AS varchar(8)) AS MemberStatus;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* An enabled follow is one directed edge; repeated enable/disable is a no-op. */
CREATE OR ALTER PROCEDURE social.usp_SetFollow
    @FollowerUserID bigint,
    @FollowedUserID bigint,
    @Enabled bit
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Enabled IS NULL THROW 51167, N'Enabled is required.', 1;
    IF @FollowerUserID = @FollowedUserID
        THROW 51168, N'A user cannot follow themself.', 1;
    DECLARE @LockResult int, @LockResource nvarchar(255), @Changed bit = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
        SET @LockResource = CONCAT(N'social:follow:', @FollowerUserID, N':', @FollowedUserID);
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51169, N'Could not lock follow pair.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE UserID = @FollowerUserID)
           OR NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE UserID = @FollowedUserID)
            THROW 51165, N'User not found.', 1;
        IF @Enabled = 1 AND
           (NOT EXISTS (SELECT 1 FROM auth.UserAccount
                        WHERE UserID = @FollowerUserID AND AccountStatus = 'ACTIVE')
            OR NOT EXISTS (SELECT 1 FROM auth.UserAccount
                           WHERE UserID = @FollowedUserID AND AccountStatus = 'ACTIVE'))
            THROW 51170, N'Both users must be active to follow.', 1;
        IF @Enabled = 1 AND NOT EXISTS
        (
            SELECT 1 FROM social.Follows AS edge
            WHERE edge.$from_id = (SELECT follower.$node_id FROM auth.UserAccount AS follower
                                   WHERE follower.UserID = @FollowerUserID)
              AND edge.$to_id = (SELECT followed.$node_id FROM auth.UserAccount AS followed
                                 WHERE followed.UserID = @FollowedUserID)
        )
        BEGIN
            INSERT INTO social.Follows ($from_id,$to_id)
            SELECT follower.$node_id, followed.$node_id
            FROM auth.UserAccount AS follower, auth.UserAccount AS followed
            WHERE follower.UserID = @FollowerUserID AND followed.UserID = @FollowedUserID;
            SET @Changed = 1;
        END;
        IF @Enabled = 0
        BEGIN
            DELETE edge FROM social.Follows AS edge
            WHERE edge.$from_id = (SELECT follower.$node_id FROM auth.UserAccount AS follower
                                   WHERE follower.UserID = @FollowerUserID)
              AND edge.$to_id = (SELECT followed.$node_id FROM auth.UserAccount AS followed
                                 WHERE followed.UserID = @FollowedUserID);
            IF @@ROWCOUNT > 0 SET @Changed = 1;
        END;
        IF @Changed = 1
            INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
            VALUES (@FollowerUserID,CASE WHEN @Enabled = 1 THEN 'FOLLOW' ELSE 'UNFOLLOW' END,
                    'USER',@FollowedUserID);
        COMMIT TRANSACTION;
        SELECT @Enabled AS IsFollowing;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* NULL reaction removes an edge, including when access was later revoked. */
CREATE OR ALTER PROCEDURE social.usp_SetReaction
    @UserID bigint,
    @ContentID bigint,
    @ReactionType varchar(12) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ReactionType IS NOT NULL
       AND @ReactionType NOT IN ('LIKE','HELPFUL','INSIGHTFUL')
        THROW 51171, N'Unknown reaction type.', 1;
    DECLARE @LockResult int, @LockResource nvarchar(255),
            @CommunityID bigint, @ExistingType varchar(12),
            @Changed bit = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE UserID = @UserID)
            THROW 51165, N'User not found.', 1;
        IF NOT EXISTS (SELECT 1 FROM social.ContentItem WHERE ContentID = @ContentID)
            THROW 51172, N'Content not found.', 1;
        IF @ReactionType IS NOT NULL
        BEGIN
            SELECT @CommunityID = CommunityID
            FROM social.vAccessibleContent
            WHERE UserID = @UserID AND ContentID = @ContentID;
            IF @CommunityID IS NULL
                THROW 51173, N'Content is not accessible to this user.', 1;
            SET @LockResource = CONCAT(N'social:community:', @CommunityID, N':membership');
            EXEC @LockResult = sys.sp_getapplock
                @Resource = @LockResource,
                @LockMode = 'Shared', @LockOwner = 'Transaction', @LockTimeout = 10000;
            IF @LockResult < 0 THROW 51150, N'Could not lock community membership.', 1;
            IF NOT EXISTS
            (
                SELECT 1 FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
                WHERE ContentID = @ContentID AND ContentStatus = 'PUBLISHED'
            ) OR NOT EXISTS
            (
                SELECT 1 FROM social.vAccessibleContent
                WHERE UserID = @UserID AND ContentID = @ContentID
                  AND CommunityID = @CommunityID
            ) THROW 51173, N'Content is not accessible to this user.', 1;
        END;
        SET @LockResource = CONCAT(N'social:reaction:', @UserID, N':', @ContentID);
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51174, N'Could not lock reaction pair.', 1;
        SELECT @ExistingType = edge.ReactionType
        FROM social.ReactTo AS edge
        WHERE edge.$from_id = (SELECT person.$node_id FROM auth.UserAccount AS person
                               WHERE person.UserID = @UserID)
          AND edge.$to_id = (SELECT item.$node_id FROM social.ContentItem AS item
                             WHERE item.ContentID = @ContentID);
        IF @ReactionType IS NULL AND @ExistingType IS NOT NULL
        BEGIN
            DELETE edge FROM social.ReactTo AS edge
            WHERE edge.$from_id = (SELECT person.$node_id FROM auth.UserAccount AS person
                                   WHERE person.UserID = @UserID)
              AND edge.$to_id = (SELECT item.$node_id FROM social.ContentItem AS item
                                 WHERE item.ContentID = @ContentID);
            SET @Changed = 1;
        END
        ELSE IF @ReactionType IS NOT NULL AND @ExistingType IS NULL
        BEGIN
            INSERT INTO social.ReactTo ($from_id,$to_id,ReactionType)
            SELECT person.$node_id,item.$node_id,@ReactionType
            FROM auth.UserAccount AS person,social.ContentItem AS item
            WHERE person.UserID = @UserID AND item.ContentID = @ContentID;
            SET @Changed = 1;
        END
        ELSE IF @ReactionType IS NOT NULL AND @ExistingType <> @ReactionType
        BEGIN
            UPDATE social.ReactTo SET ReactionType = @ReactionType
            WHERE $from_id = (SELECT person.$node_id FROM auth.UserAccount AS person
                              WHERE person.UserID = @UserID)
              AND $to_id = (SELECT item.$node_id FROM social.ContentItem AS item
                            WHERE item.ContentID = @ContentID);
            SET @Changed = 1;
        END;
        IF @Changed = 1
            INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
            VALUES (@UserID,CASE WHEN @ReactionType IS NULL THEN 'REACTION_REMOVE'
                                 ELSE 'REACTION_SET' END,'CONTENT',@ContentID);
        COMMIT TRANSACTION;
        SELECT @ReactionType AS ReactionType;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Hiding a post also hides its comments and queues deletion of their indexes. */
CREATE OR ALTER PROCEDURE social.usp_ModerateContent
    @ActorUserID bigint,
    @ContentID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @CommunityID bigint, @OwnerUserID bigint, @ActorRole varchar(10),
            @ContentKind varchar(8), @ContentStatus varchar(12), @LockResult int,
            @LockResource nvarchar(255), @ChangedRows int = 0, @QueuedRows int = 0;
    DECLARE @Locations TABLE (CommunityID bigint PRIMARY KEY);
    DECLARE @Affected TABLE (ContentID bigint PRIMARY KEY);
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO @Locations (CommunityID)
        SELECT community.CommunityID
        FROM social.ContentItem AS item,
             social.PublishedIn AS location,
             social.Community AS community
        WHERE MATCH(item-(location)->community)
          AND item.ContentID = @ContentID AND item.Kind IN ('POST','DOCUMENT')
        UNION
        SELECT community.CommunityID
        FROM social.ContentItem AS comment,
             social.CommentOn AS commentOn,
             social.ContentItem AS post,
             social.PublishedIn AS location,
             social.Community AS community
        WHERE MATCH(comment-(commentOn)->post)
          AND MATCH(post-(location)->community)
          AND comment.ContentID = @ContentID AND comment.Kind = 'COMMENT'
          AND post.Kind = 'POST';
        IF (SELECT COUNT(*) FROM @Locations) <> 1
            THROW 51175, N'Content must belong to exactly one community.', 1;
        SELECT @CommunityID = CommunityID FROM @Locations;
        SET @LockResource = CONCAT(N'social:community:', @CommunityID, N':membership');
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Shared', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0 THROW 51150, N'Could not lock community membership.', 1;

        SELECT @OwnerUserID = OwnerUserID FROM social.Community
        WHERE CommunityID = @CommunityID;
        IF NOT EXISTS (SELECT 1 FROM auth.UserAccount
                       WHERE UserID = @ActorUserID AND AccountStatus = 'ACTIVE')
            THROW 51158, N'Active actor not found.', 1;
        IF @ActorUserID = @OwnerUserID SET @ActorRole = 'OWNER';
        ELSE
            SELECT @ActorRole = edge.[Role]
            FROM auth.UserAccount AS actor,
                 social.MemberOf AS edge,
                 social.Community AS community
            WHERE MATCH(actor-(edge)->community)
              AND actor.UserID = @ActorUserID AND community.CommunityID = @CommunityID
              AND edge.MemberStatus = 'ACTIVE' AND edge.EndedAt IS NULL
              AND edge.[Role] IN ('ADMIN','MODERATOR');
        IF @ActorRole IS NULL OR @ActorRole NOT IN ('OWNER','ADMIN','MODERATOR')
            THROW 51176, N'Only owner, admin or moderator may hide content.', 1;
        SELECT @ContentKind = Kind, @ContentStatus = ContentStatus
        FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
        WHERE ContentID = @ContentID;
        IF @ContentStatus NOT IN ('PUBLISHED','HIDDEN') OR @ContentStatus IS NULL
            THROW 51177, N'Only published or already hidden content can be moderated.', 1;

        INSERT INTO @Affected (ContentID) VALUES (@ContentID);
        IF @ContentKind = 'POST'
            INSERT INTO @Affected (ContentID)
            SELECT comment.ContentID
            FROM social.ContentItem AS comment,
                 social.CommentOn AS relation,
                 social.ContentItem AS post
            WHERE MATCH(comment-(relation)->post)
              AND post.ContentID = @ContentID AND comment.Kind = 'COMMENT';

        UPDATE item SET ContentStatus = 'HIDDEN', AllowRag = 0,
                        UpdatedAt = SYSUTCDATETIME()
        FROM social.ContentItem AS item
        JOIN @Affected AS affected ON affected.ContentID = item.ContentID
        WHERE item.ContentStatus IN ('PUBLISHED','HIDDEN')
          AND (item.ContentStatus <> 'HIDDEN' OR item.AllowRag <> 0);
        SET @ChangedRows = @@ROWCOUNT;
        UPDATE revision SET CommentStatus = 'HIDDEN'
        FROM social.CommentRevision AS revision
        JOIN @Affected AS affected ON affected.ContentID = revision.ContentID
        WHERE revision.IsCurrent = 1 AND revision.CommentStatus = 'VISIBLE';
        SET @ChangedRows = @ChangedRows + @@ROWCOUNT;

        /* HOLDLOCK protects the absent-event check from concurrent moderation. */
        INSERT INTO ops.IndexOutbox (SourceRevisionID,ModelID,Operation)
        SELECT source.SourceRevisionID, model.ModelID, 'DELETE'
        FROM knowledge.SourceRevision AS source
        JOIN @Affected AS affected ON affected.ContentID = source.ContentID
        CROSS JOIN knowledge.EmbeddingModel AS model
        WHERE NOT EXISTS
        (
            SELECT 1 FROM ops.IndexOutbox AS queued WITH (UPDLOCK,HOLDLOCK)
            WHERE queued.SourceRevisionID = source.SourceRevisionID
              AND queued.ModelID = model.ModelID AND queued.Operation = 'DELETE'
        );
        SET @QueuedRows = @@ROWCOUNT;
        IF @ChangedRows > 0 OR @QueuedRows > 0
            INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
            VALUES (@ActorUserID,'MODERATE_HIDE','CONTENT',@ContentID);
        COMMIT TRANSACTION;
        SELECT @ContentID AS ContentID, CAST('HIDDEN' AS varchar(12)) AS ContentStatus,
               @ChangedRows AS ChangedRows, @QueuedRows AS QueuedDeleteEvents;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
