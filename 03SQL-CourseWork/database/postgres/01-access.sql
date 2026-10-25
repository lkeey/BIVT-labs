-- Central live ACL. Every externally visible read joins these functions.
CREATE OR REPLACE FUNCTION auth.can_read_community(p_userid bigint,p_communityid bigint)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.useraccount u JOIN social.community c ON c.communityid=p_communityid
    WHERE u.userid=p_userid AND u.accountstatus='ACTIVE' AND c.status='ACTIVE'
      AND NOT EXISTS (
        SELECT 1 FROM social.memberof m WHERE m.userid=p_userid AND m.communityid=p_communityid
          AND m.memberstatus IN ('BLOCKED','BANNED') AND m.endedat IS NULL)
      AND (c.visibility='PUBLIC' OR c.owneruserid=p_userid OR EXISTS (
        SELECT 1 FROM social.memberof m WHERE m.userid=p_userid AND m.communityid=p_communityid
          AND m.memberstatus='ACTIVE' AND m.endedat IS NULL))
  );
$$;
CREATE OR REPLACE FUNCTION auth.can_write_community(p_userid bigint,p_communityid bigint)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT auth.can_read_community(p_userid,p_communityid) AND EXISTS (
    SELECT 1 FROM social.community c WHERE c.communityid=p_communityid AND
      (c.owneruserid=p_userid OR EXISTS (
        SELECT 1 FROM social.memberof m WHERE m.userid=p_userid AND m.communityid=p_communityid
          AND m.memberstatus='ACTIVE' AND m.endedat IS NULL))
  );
$$;
CREATE OR REPLACE FUNCTION social.accessible_content(p_userid bigint)
RETURNS TABLE(contentid bigint,kind varchar,communityid bigint,authoruserid bigint,publishedat timestamptz)
LANGUAGE sql STABLE AS $$
  WITH located AS (
    SELECT i.contentid,i.kind,p.communityid
    FROM social.contentitem i JOIN social.publishedin p ON p.contentid=i.contentid
    WHERE i.kind IN ('POST','DOCUMENT')
    UNION ALL
    SELECT i.contentid,i.kind,p.communityid
    FROM social.contentitem i JOIN social.commenton co ON co.commentcontentid=i.contentid
    JOIN social.contentitem parent ON parent.contentid=co.postcontentid
    JOIN social.publishedin p ON p.contentid=parent.contentid
    WHERE i.kind='COMMENT' AND parent.kind='POST' AND parent.contentstatus='PUBLISHED'
  )
  SELECT i.contentid,i.kind,l.communityid,a.userid,i.publishedat
  FROM located l JOIN social.contentitem i ON i.contentid=l.contentid
  JOIN social.authored a ON a.contentid=i.contentid
  WHERE i.contentstatus='PUBLISHED' AND auth.can_read_community(p_userid,l.communityid)
    AND ((i.kind='POST' AND EXISTS (SELECT 1 FROM social.postrevision r WHERE r.contentid=i.contentid AND r.iscurrent))
      OR (i.kind='COMMENT' AND EXISTS (SELECT 1 FROM social.commentrevision r WHERE r.contentid=i.contentid AND r.iscurrent AND r.commentstatus='VISIBLE'))
      OR (i.kind='DOCUMENT' AND EXISTS (
        SELECT 1 FROM social.documentdetail d JOIN knowledge.documentversion v ON v.contentid=d.contentid
        WHERE d.contentid=i.contentid AND d.documentstatus='READY' AND v.iscurrent)))
$$;
CREATE OR REPLACE VIEW knowledge.vcurrentragchunks AS
SELECT ch.chunkid,ch.sourcerevisionid,s.contentid,ch.chunktext,ch.pageno,ch.startoffset,ch.endoffset,
       ch.chunkhash,i.kind,COALESCE(d.title,left(p.body,120),left(cm.body,120)) AS title
FROM knowledge.chunk ch JOIN knowledge.sourcerevision s ON s.sourcerevisionid=ch.sourcerevisionid
JOIN social.contentitem i ON i.contentid=s.contentid
LEFT JOIN social.postrevision p ON p.revisionid=s.postrevisionid
LEFT JOIN social.commentrevision cm ON cm.revisionid=s.commentrevisionid
LEFT JOIN social.documentdetail d ON d.contentid=s.contentid
WHERE i.contentstatus='PUBLISHED' AND i.allowrag AND s.iscurrent AND s.processingstatus='READY'
  AND ch.chunkstatus='READY'
  AND (p.revisionid IS NULL OR p.iscurrent)
  AND (cm.revisionid IS NULL OR (cm.iscurrent AND cm.commentstatus='VISIBLE'))
  AND (s.documentversionid IS NULL OR EXISTS (
    SELECT 1 FROM knowledge.documentversion v WHERE v.documentversionid=s.documentversionid AND v.iscurrent));
CREATE OR REPLACE FUNCTION knowledge.accessible_chunks(p_userid bigint)
RETURNS TABLE(chunkid bigint,sourcerevisionid bigint,contentid bigint,chunktext text,pageno integer,
              startoffset integer,endoffset integer,chunkhash bytea,kind varchar,title text,
              communityid bigint,authoruserid bigint)
LANGUAGE sql STABLE AS $$
 SELECT ch.chunkid,ch.sourcerevisionid,ch.contentid,ch.chunktext,ch.pageno,ch.startoffset,ch.endoffset,
        ch.chunkhash,ch.kind,ch.title,access.communityid,access.authoruserid
 FROM knowledge.vcurrentragchunks ch JOIN social.accessible_content(p_userid) access ON access.contentid=ch.contentid;
$$;
CREATE INDEX IF NOT EXISTS ix_chunk_russian_fts ON knowledge.chunk USING gin (to_tsvector('russian',chunktext));

-- Projection maintenance. An obsolete source is never searched, even before its cleanup event is handled.
CREATE OR REPLACE FUNCTION ops.enqueue_source_revision()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_modelid integer;
BEGIN
 SELECT modelid INTO v_modelid FROM knowledge.embeddingmodel WHERE isactive ORDER BY modelid LIMIT 1;
 INSERT INTO ops.indexoutbox(sourcerevisionid,modelid,operation)
 VALUES (NEW.sourcerevisionid,v_modelid,CASE WHEN NEW.iscurrent THEN 'UPSERT' ELSE 'DELETE' END)
 ON CONFLICT DO NOTHING;
 RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS tr_enqueue_source_revision ON knowledge.sourcerevision;
CREATE TRIGGER tr_enqueue_source_revision AFTER INSERT OR UPDATE OF iscurrent ON knowledge.sourcerevision
FOR EACH ROW EXECUTE FUNCTION ops.enqueue_source_revision();
CREATE OR REPLACE FUNCTION ops.enqueue_content_revocation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.contentstatus='PUBLISHED' AND (NEW.contentstatus<>'PUBLISHED' OR NOT NEW.allowrag) THEN
   INSERT INTO ops.indexoutbox(sourcerevisionid,modelid,operation)
   SELECT s.sourcerevisionid,em.modelid,'DELETE'
   FROM knowledge.sourcerevision s CROSS JOIN LATERAL
     (SELECT modelid FROM knowledge.embeddingmodel WHERE isactive ORDER BY modelid LIMIT 1) em
   WHERE s.contentid=NEW.contentid AND s.iscurrent
   ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS tr_enqueue_content_revocation ON social.contentitem;
CREATE TRIGGER tr_enqueue_content_revocation AFTER UPDATE OF contentstatus,allowrag ON social.contentitem
FOR EACH ROW EXECUTE FUNCTION ops.enqueue_content_revocation();
