-- A readable SQL feed: followed authors, joined communities, then newest content.
-- This query persists no generated recommendations and checks live access on every read.
CREATE OR REPLACE FUNCTION social.usp_buildrecommendationfeed(p_userid bigint,p_limit integer DEFAULT 20)
RETURNS TABLE(rank integer,contentid bigint,kind text,score double precision,reasoncode text,
 reasontext text,communityid bigint,authoruserid bigint)
LANGUAGE plpgsql AS $$
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN
   RAISE EXCEPTION 'Invalid feed limit' USING ERRCODE='22023';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount u WHERE u.userid=p_userid AND u.accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active user required' USING ERRCODE='42501';
 END IF;
 RETURN QUERY
 WITH candidates AS (
   SELECT a.*, CASE
     WHEN EXISTS (SELECT 1 FROM social.follows f WHERE f.followeruserid=p_userid AND f.followeduserid=a.authoruserid) THEN 2
     WHEN EXISTS (SELECT 1 FROM social.memberof m WHERE m.userid=p_userid AND m.communityid=a.communityid
       AND m.memberstatus='ACTIVE' AND m.endedat IS NULL) THEN 1
     ELSE 0 END AS priority
   FROM social.accessible_content(p_userid) a WHERE a.kind IN ('POST','DOCUMENT')
 ), ranked AS (
   SELECT c.*,row_number() OVER (ORDER BY c.priority DESC,c.publishedat DESC,c.contentid DESC)::integer AS ordinal
   FROM candidates c
 )
 SELECT r.ordinal,r.contentid,r.kind::text,(r.priority/2.0)::double precision,
   CASE r.priority WHEN 2 THEN 'FOLLOWED_AUTHOR' WHEN 1 THEN 'MEMBER_COMMUNITY' ELSE 'FRESH' END,
   CASE r.priority WHEN 2 THEN 'Автор, на которого вы подписаны' WHEN 1 THEN 'Из вашего сообщества' ELSE 'Недавно опубликовано' END,
   r.communityid,r.authoruserid
 FROM ranked r ORDER BY r.ordinal LIMIT p_limit;
END;
$$;
