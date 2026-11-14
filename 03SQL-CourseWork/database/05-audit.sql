IF OBJECT_ID(N'ops.AuditEvent', N'U') IS NULL
BEGIN
    CREATE TABLE ops.AuditEvent
    (
        AuditEventID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditEvent PRIMARY KEY,
        ActorUserID bigint NULL,
        EventType varchar(40) NOT NULL,
        EntityType varchar(40) NOT NULL,
        EntityID bigint NOT NULL,
        CorrelationID uniqueidentifier NULL,
        Details nvarchar(max) NULL,
        OccurredAt datetime2(3) NOT NULL CONSTRAINT DF_AuditEvent_OccurredAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_AuditEvent_Actor FOREIGN KEY (ActorUserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT CK_AuditEvent_Details CHECK (Details IS NULL OR ISJSON(Details) = 1)
    );
END;
GO
