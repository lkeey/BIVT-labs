-- User-facing reads; no caller-supplied SQL identity is trusted by the API.
CREATE OR REPLACE FUNCTION auth.usp_getuserprofile(p_userid bigint,p_profileuserid bigint)
RETURNS TABLE(userid bigint,displayname text,bio text,followedbyme boolean)
LANGUAGE sql STABLE AS $$
 SELECT u.userid,p.displayname::text,p.bio::text,
   EXISTS (SELECT 1 FROM social.follows f WHERE f.followeruserid=p_userid AND f.followeduserid=u.userid)
 FROM auth.useraccount u JOIN auth.userprofile p ON p.userid=u.userid
 WHERE u.userid=p_profileuserid AND u.accountstatus='ACTIVE'
   AND EXISTS (SELECT 1 FROM auth.useraccount me WHERE me.userid=p_userid AND me.accountstatus='ACTIVE')
   AND (p.profilevisibility='PUBLIC' OR u.userid=p_userid);
$$;
CREATE OR REPLACE FUNCTION social.usp_listcommunities(p_userid bigint,p_aftercommunityid bigint,p_limit integer)
RETURNS TABLE(communityid bigint,slug text,name text,description text,visibility text,owneruserid bigint,membershipstatus text)
LANGUAGE sql STABLE AS $$
 SELECT c.communityid,c.slug::text,c.communityname::text,c.description::text,c.visibility::text,c.owneruserid,
   CASE WHEN c.owneruserid=p_userid THEN 'ACTIVE' ELSE coalesce(m.memberstatus,'NONE') END::text
 FROM social.community c LEFT JOIN LATERAL (
   SELECT x.memberstatus FROM social.memberof x WHERE x.userid=p_userid AND x.communityid=c.communityid
     AND x.endedat IS NULL ORDER BY x.membershipid DESC LIMIT 1) m ON true
 WHERE auth.can_read_community(p_userid,c.communityid)
   AND c.communityid>coalesce(p_aftercommunityid,0) AND p_limit BETWEEN 1 AND 50
 ORDER BY c.communityid LIMIT p_limit+1;
$$;
CREATE OR REPLACE FUNCTION social.usp_getcommunity(p_userid bigint,p_communityid bigint)
RETURNS TABLE(communityid bigint,slug text,name text,description text,visibility text,owneruserid bigint,membershipstatus text)
LANGUAGE sql STABLE AS $$
 SELECT c.communityid,c.slug::text,c.communityname::text,c.description::text,c.visibility::text,c.owneruserid,
   CASE WHEN c.owneruserid=p_userid THEN 'ACTIVE' ELSE coalesce(m.memberstatus,'NONE') END::text
 FROM social.community c LEFT JOIN LATERAL (
   SELECT x.memberstatus FROM social.memberof x WHERE x.userid=p_userid AND x.communityid=c.communityid
     AND x.endedat IS NULL ORDER BY x.membershipid DESC LIMIT 1) m ON true
 WHERE c.communityid=p_communityid AND auth.can_read_community(p_userid,c.communityid);
$$;
CREATE OR REPLACE FUNCTION social.usp_listposts(p_userid bigint,p_communityid bigint,p_aftercontentid bigint,p_limit integer)
RETURNS TABLE(contentid bigint,communityid bigint,authoruserid bigint,body text,publishedat timestamptz)
LANGUAGE sql STABLE AS $$
 SELECT a.contentid,a.communityid,a.authoruserid,r.body,a.publishedat
 FROM social.accessible_content(p_userid) a JOIN social.postrevision r ON r.contentid=a.contentid AND r.iscurrent
 WHERE a.kind='POST' AND a.communityid=p_communityid AND a.contentid>coalesce(p_aftercontentid,0)
   AND p_limit BETWEEN 1 AND 50 ORDER BY a.contentid LIMIT p_limit+1;
$$;
CREATE OR REPLACE FUNCTION social.usp_getpost(p_userid bigint,p_postid bigint)
RETURNS TABLE(contentid bigint,communityid bigint,authoruserid bigint,body text,publishedat timestamptz)
LANGUAGE sql STABLE AS $$
 SELECT a.contentid,a.communityid,a.authoruserid,r.body,a.publishedat
 FROM social.accessible_content(p_userid) a JOIN social.postrevision r ON r.contentid=a.contentid AND r.iscurrent
 WHERE a.kind='POST' AND a.contentid=p_postid;
$$;
CREATE OR REPLACE FUNCTION social.usp_listcomments(p_userid bigint,p_postid bigint,p_aftercontentid bigint,p_limit integer)
RETURNS TABLE(contentid bigint,postid bigint,authoruserid bigint,body text,publishedat timestamptz)
LANGUAGE sql STABLE AS $$
 SELECT a.contentid,co.postcontentid,a.authoruserid,r.body,a.publishedat
 FROM social.accessible_content(p_userid) a JOIN social.commenton co ON co.commentcontentid=a.contentid
 JOIN social.commentrevision r ON r.contentid=a.contentid AND r.iscurrent AND r.commentstatus='VISIBLE'
 WHERE a.kind='COMMENT' AND co.postcontentid=p_postid AND a.contentid>coalesce(p_aftercontentid,0)
   AND EXISTS (SELECT 1 FROM social.accessible_content(p_userid) parent WHERE parent.contentid=p_postid AND parent.kind='POST')
   AND p_limit BETWEEN 1 AND 50 ORDER BY a.contentid LIMIT p_limit+1;
$$;
CREATE OR REPLACE FUNCTION social.usp_getcomment(p_userid bigint,p_commentid bigint)
RETURNS TABLE(contentid bigint,postid bigint,authoruserid bigint,body text,publishedat timestamptz)
LANGUAGE sql STABLE AS $$
 SELECT a.contentid,co.postcontentid,a.authoruserid,r.body,a.publishedat
 FROM social.accessible_content(p_userid) a JOIN social.commenton co ON co.commentcontentid=a.contentid
 JOIN social.commentrevision r ON r.contentid=a.contentid AND r.iscurrent AND r.commentstatus='VISIBLE'
 WHERE a.kind='COMMENT' AND a.contentid=p_commentid;
$$;
CREATE OR REPLACE FUNCTION knowledge.usp_listdocuments(p_userid bigint,p_communityid bigint,p_aftercontentid bigint,p_limit integer)
RETURNS TABLE(contentid bigint,communityid bigint,authoruserid bigint,title text,mimetype text,
 versionno integer,processingstatus text)
LANGUAGE sql STABLE AS $$
 SELECT a.contentid,a.communityid,a.authoruserid,d.title::text,v.mimetype::text,v.versionno,d.documentstatus::text
 FROM social.accessible_content(p_userid) a JOIN social.documentdetail d ON d.contentid=a.contentid
 JOIN knowledge.documentversion v ON v.contentid=a.contentid AND v.iscurrent
 WHERE a.kind='DOCUMENT' AND d.documentstatus='READY' AND a.communityid=p_communityid
   AND a.contentid>coalesce(p_aftercontentid,0) AND p_limit BETWEEN 1 AND 50
 ORDER BY a.contentid LIMIT p_limit+1;
$$;
CREATE OR REPLACE FUNCTION knowledge.usp_getdocument(p_userid bigint,p_documentid bigint)
RETURNS TABLE(contentid bigint,communityid bigint,authoruserid bigint,title text,mimetype text,
 versionno integer,processingstatus text)
LANGUAGE sql STABLE AS $$
 SELECT i.contentid,p.communityid,a.userid,d.title::text,v.mimetype::text,v.versionno,d.documentstatus::text
 FROM social.contentitem i JOIN social.publishedin p ON p.contentid=i.contentid
 JOIN social.authored a ON a.contentid=i.contentid
 JOIN social.documentdetail d ON d.contentid=i.contentid
 JOIN knowledge.documentversion v ON v.contentid=i.contentid AND v.iscurrent
 WHERE i.contentid=p_documentid AND i.kind='DOCUMENT' AND i.contentstatus='PUBLISHED'
   AND auth.can_read_community(p_userid,p.communityid)
   AND (d.documentstatus='READY' OR a.userid=p_userid);
$$;
CREATE OR REPLACE FUNCTION knowledge.usp_getdocumentfile(p_userid bigint,p_contentid bigint)
RETURNS TABLE(documentversionid bigint,filename text,mimetype text,sizebytes bigint,sha256 bytea,
 filebytes bytea,plaintext text)
LANGUAGE sql STABLE AS $$
 SELECT v.documentversionid,v.filename::text,v.mimetype::text,v.sizebytes,v.sha256,v.filebytes,v.plaintext
 FROM social.accessible_content(p_userid) a JOIN social.documentdetail d ON d.contentid=a.contentid
 JOIN knowledge.documentversion v ON v.contentid=a.contentid AND v.iscurrent
 WHERE a.contentid=p_contentid AND a.kind='DOCUMENT' AND d.documentstatus='READY' AND v.uploadstatus='STORED';
$$;
CREATE OR REPLACE FUNCTION social.usp_listpendingmemberships(p_actoruserid bigint,p_communityid bigint,
 p_aftermembershipid bigint,p_limit integer)
RETURNS TABLE(membershipid bigint,userid bigint,displayname text,joinedat timestamptz)
LANGUAGE sql STABLE AS $$
 SELECT m.membershipid,m.userid,p.displayname::text,m.joinedat
 FROM social.memberof m JOIN auth.userprofile p ON p.userid=m.userid
 JOIN social.community c ON c.communityid=m.communityid
 WHERE m.communityid=p_communityid AND m.memberstatus='PENDING' AND m.endedat IS NULL
   AND m.membershipid>coalesce(p_aftermembershipid,0) AND p_limit BETWEEN 1 AND 100
   AND c.status='ACTIVE' AND auth.can_read_community(p_actoruserid,c.communityid)
   AND (c.owneruserid=p_actoruserid OR EXISTS (
      SELECT 1 FROM social.memberof admin WHERE admin.communityid=p_communityid
        AND admin.userid=p_actoruserid AND admin.memberstatus='ACTIVE' AND admin.role='ADMIN' AND admin.endedat IS NULL))
 ORDER BY m.membershipid LIMIT p_limit;
$$;
