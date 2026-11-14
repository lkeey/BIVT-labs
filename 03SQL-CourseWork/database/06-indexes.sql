/* One current revision and one current membership per entity. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.PostRevision') AND name = N'UX_PostRevision_Current')
    CREATE UNIQUE INDEX UX_PostRevision_Current ON social.PostRevision(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.CommentRevision') AND name = N'UX_CommentRevision_Current')
    CREATE UNIQUE INDEX UX_CommentRevision_Current ON social.CommentRevision(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.DocumentVersion') AND name = N'UX_DocumentVersion_Current')
    CREATE UNIQUE INDEX UX_DocumentVersion_Current ON social.DocumentVersion(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.MemberOf') AND name = N'UX_MemberOf_Current')
    CREATE UNIQUE INDEX UX_MemberOf_Current ON social.MemberOf(UserID,CommunityID) WHERE EndedAt IS NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.MemberOf') AND name = N'IX_MemberOf_Community')
    CREATE INDEX IX_MemberOf_Community ON social.MemberOf(CommunityID,MemberStatus,EndedAt,UserID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ContentItem') AND name = N'IX_ContentItem_Community')
    CREATE INDEX IX_ContentItem_Community ON social.ContentItem(CommunityID,ContentStatus,Kind,ContentID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ContentItem') AND name = N'IX_ContentItem_Author')
    CREATE INDEX IX_ContentItem_Author ON social.ContentItem(AuthorUserID,PublishedAt DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ContentItem') AND name = N'IX_ContentItem_Parent')
    CREATE INDEX IX_ContentItem_Parent ON social.ContentItem(ParentPostID,ContentID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ReactTo') AND name = N'IX_ReactTo_Content')
    CREATE INDEX IX_ReactTo_Content ON social.ReactTo(ContentID,UserID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.Follows') AND name = N'UX_Follows_Pair')
    CREATE UNIQUE INDEX UX_Follows_Pair ON social.Follows($from_id,$to_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.Follows') AND name = N'IX_Follows_To')
    CREATE INDEX IX_Follows_To ON social.Follows($to_id,$from_id);
GO
