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
        SELECT 1 FROM social.documentdetail d JOIN social.documentversion v ON v.contentid=d.contentid
        WHERE d.contentid=i.contentid AND d.documentstatus='READY' AND v.iscurrent)))
$$;
