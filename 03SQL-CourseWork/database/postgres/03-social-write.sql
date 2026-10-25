-- PostgreSQL entry points mirror the Go API's SQL Server stored procedures.
CREATE OR REPLACE FUNCTION auth.usp_getorcreatefirebaseuser(p_firebaseuid text,p_email text DEFAULT NULL,
 p_displayname text DEFAULT NULL)
RETURNS TABLE(userid bigint) LANGUAGE plpgsql AS $$
DECLARE v_hash text; v_user bigint;
BEGIN
 IF p_firebaseuid IS NULL OR length(p_firebaseuid) NOT BETWEEN 1 AND 128 THEN
   RAISE EXCEPTION 'Verified Firebase UID required' USING ERRCODE='22023';
 END IF;
 v_hash:=encode(digest(p_firebaseuid,'sha256'),'hex');
 SELECT ei.userid INTO v_user FROM auth.externalidentity ei WHERE ei.firebaseuid=p_firebaseuid;
 IF v_user IS NULL THEN
   -- The UID-derived login avoids email-based account merging.
   INSERT INTO auth.useraccount(login,emailnormalized)
   VALUES ('fb-'||v_hash,'fb-'||v_hash||'@identity.invalid')
   ON CONFLICT (login) DO NOTHING RETURNING auth.useraccount.userid INTO v_user;
   IF v_user IS NOT NULL THEN
     INSERT INTO auth.userprofile(userid,displayname)
       VALUES (v_user,COALESCE(NULLIF(btrim(left(p_displayname,120)),''),'Пользователь '||left(v_hash,8)));
     INSERT INTO auth.externalidentity(firebaseuid,userid) VALUES (p_firebaseuid,v_user);
   ELSE
     SELECT ei.userid INTO v_user FROM auth.externalidentity ei WHERE ei.firebaseuid=p_firebaseuid;
   END IF;
 END IF;
 IF v_user IS NULL OR NOT EXISTS (SELECT 1 FROM auth.useraccount u WHERE u.userid=v_user AND u.accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Account inactive or identity collision' USING ERRCODE='42501';
 END IF;
 userid:=v_user; RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION social.usp_createcommunity(p_owneruserid bigint,p_slug text,p_name text,
 p_visibility text,p_description text DEFAULT NULL)
RETURNS TABLE(communityid bigint,created boolean) LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount u WHERE u.userid=p_owneruserid AND u.accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active owner required' USING ERRCODE='42501';
 END IF;
 IF p_slug !~ '^[a-z0-9-]{3,100}$' OR NULLIF(btrim(p_name),'') IS NULL OR p_visibility NOT IN ('PUBLIC','PRIVATE') THEN
   RAISE EXCEPTION 'Invalid community fields' USING ERRCODE='22023';
 END IF;
 INSERT INTO social.community(owneruserid,slug,communityname,description,visibility)
 VALUES (p_owneruserid,p_slug,p_name,p_description,p_visibility)
 RETURNING social.community.communityid INTO communityid;
 INSERT INTO social.memberof(userid,communityid,memberstatus,role)
 VALUES (p_owneruserid,communityid,'ACTIVE','OWNER');
 created:=true; RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_requestmembership(p_userid bigint,p_communityid bigint)
RETURNS TABLE(membershipid bigint,memberstatus varchar,role varchar,created boolean)
LANGUAGE plpgsql AS $$
DECLARE v_visibility varchar; v_owner bigint;
BEGIN
 SELECT c.visibility,c.owneruserid INTO v_visibility,v_owner FROM social.community c
 WHERE c.communityid=p_communityid AND c.status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Community not found' USING ERRCODE='P0002'; END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount u WHERE u.userid=p_userid AND u.accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active account required' USING ERRCODE='42501';
 END IF;
 SELECT m.membershipid,m.memberstatus,m.role INTO membershipid,memberstatus,role
 FROM social.memberof m WHERE m.userid=p_userid AND m.communityid=p_communityid AND m.endedat IS NULL
 ORDER BY m.membershipid DESC LIMIT 1 FOR UPDATE;
 IF FOUND THEN
   IF memberstatus IN ('BLOCKED','BANNED') THEN RAISE EXCEPTION 'Membership blocked' USING ERRCODE='42501'; END IF;
   created:=false; RETURN NEXT; RETURN;
 END IF;
 INSERT INTO social.memberof(userid,communityid,memberstatus,role)
 VALUES (p_userid,p_communityid,CASE WHEN v_visibility='PUBLIC' OR v_owner=p_userid THEN 'ACTIVE' ELSE 'PENDING' END,
   CASE WHEN v_owner=p_userid THEN 'OWNER' ELSE 'MEMBER' END)
 RETURNING social.memberof.membershipid,social.memberof.memberstatus,social.memberof.role
 INTO membershipid,memberstatus,role;
 created:=true; RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_setmembership(p_actoruserid bigint,p_communityid bigint,
 p_targetuserid bigint,p_memberstatus text,p_role text DEFAULT 'MEMBER')
RETURNS TABLE(membershipid bigint,memberstatus varchar,role varchar) LANGUAGE plpgsql AS $$
DECLARE v_owner bigint; v_membershipid bigint; v_currentrole text;
BEGIN
 SELECT owneruserid INTO v_owner FROM social.community WHERE communityid=p_communityid AND status='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Community not found' USING ERRCODE='P0002'; END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount WHERE userid=p_actoruserid AND accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active administrator required' USING ERRCODE='42501';
 END IF;
 IF p_actoruserid<>v_owner AND NOT EXISTS (
   SELECT 1 FROM social.memberof m WHERE m.userid=p_actoruserid AND m.communityid=p_communityid
     AND m.memberstatus='ACTIVE' AND m.role='ADMIN' AND m.endedat IS NULL) THEN
   RAISE EXCEPTION 'Membership administration forbidden' USING ERRCODE='42501';
 END IF;
 IF p_targetuserid=v_owner OR p_memberstatus NOT IN ('PENDING','ACTIVE','BLOCKED')
   OR p_role NOT IN ('ADMIN','MODERATOR','MEMBER')
   OR (p_memberstatus<>'ACTIVE' AND p_role<>'MEMBER') THEN
   RAISE EXCEPTION 'Invalid membership change' USING ERRCODE='22023';
 END IF;
 IF p_actoruserid<>v_owner AND (p_actoruserid=p_targetuserid OR p_role='ADMIN') THEN
   RAISE EXCEPTION 'Administrator cannot change self or grant admin role' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount u WHERE u.userid=p_targetuserid AND u.accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active target required' USING ERRCODE='42501';
 END IF;
 SELECT m.membershipid,m.role INTO v_membershipid,v_currentrole FROM social.memberof m
 WHERE m.userid=p_targetuserid AND m.communityid=p_communityid AND m.endedat IS NULL
 ORDER BY m.membershipid DESC LIMIT 1 FOR UPDATE;
 IF p_actoruserid<>v_owner AND v_currentrole IN ('OWNER','ADMIN') THEN
   RAISE EXCEPTION 'Administrator cannot change another admin' USING ERRCODE='42501';
 END IF;
 IF v_membershipid IS NULL THEN
   INSERT INTO social.memberof(userid,communityid,memberstatus,role)
   VALUES (p_targetuserid,p_communityid,p_memberstatus,p_role)
   RETURNING social.memberof.membershipid INTO v_membershipid;
 ELSE
   UPDATE social.memberof m SET memberstatus=p_memberstatus,role=p_role WHERE m.membershipid=v_membershipid;
 END IF;
 membershipid:=v_membershipid;memberstatus:=p_memberstatus;role:=p_role;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_leavecommunity(p_userid bigint,p_communityid bigint)
RETURNS TABLE(membershipid bigint,memberstatus varchar) LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS (SELECT 1 FROM social.community WHERE communityid=p_communityid AND owneruserid=p_userid) THEN
   RAISE EXCEPTION 'Owner cannot leave community' USING ERRCODE='42501';
 END IF;
 UPDATE social.memberof m SET memberstatus='LEFT',endedat=now()
 WHERE m.userid=p_userid AND m.communityid=p_communityid AND m.endedat IS NULL
   AND m.memberstatus IN ('PENDING','ACTIVE')
 RETURNING m.membershipid,m.memberstatus INTO membershipid,memberstatus;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active membership not found' USING ERRCODE='P0002'; END IF;
 RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_setfollow(p_followeruserid bigint,p_followeduserid bigint,p_enabled boolean)
RETURNS TABLE(enabled boolean) LANGUAGE plpgsql AS $$
BEGIN
 IF p_followeruserid=p_followeduserid THEN RAISE EXCEPTION 'Self-follow forbidden' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount WHERE userid=p_followeruserid AND accountstatus='ACTIVE')
   OR NOT EXISTS (SELECT 1 FROM auth.useraccount WHERE userid=p_followeduserid AND accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active accounts required' USING ERRCODE='42501';
 END IF;
 IF p_enabled THEN
   INSERT INTO social.follows(followeruserid,followeduserid) VALUES(p_followeruserid,p_followeduserid) ON CONFLICT DO NOTHING;
 ELSE DELETE FROM social.follows WHERE followeruserid=p_followeruserid AND followeduserid=p_followeduserid;
 END IF;
 enabled:=p_enabled;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_setreaction(p_userid bigint,p_contentid bigint,p_reactiontype text)
RETURNS TABLE(reactiontype varchar) LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM social.accessible_content(p_userid) WHERE contentid=p_contentid) THEN
   RAISE EXCEPTION 'Content unavailable' USING ERRCODE='P0002';
 END IF;
 IF p_reactiontype IS NULL THEN
   DELETE FROM social.reactto WHERE userid=p_userid AND contentid=p_contentid;
 ELSE
   IF p_reactiontype NOT IN ('LIKE','HELPFUL','INSIGHTFUL') THEN RAISE EXCEPTION 'Invalid reaction' USING ERRCODE='22023'; END IF;
   INSERT INTO social.reactto(userid,contentid,reactiontype) VALUES (p_userid,p_contentid,p_reactiontype)
   ON CONFLICT (userid,contentid) DO UPDATE SET reactiontype=EXCLUDED.reactiontype,createdat=now();
 END IF;
 reactiontype:=p_reactiontype;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_publishcontent(p_authoruserid bigint,p_communityid bigint,p_kind text,
 p_body text,p_parentpostid bigint DEFAULT NULL,p_contentid bigint DEFAULT NULL)
RETURNS TABLE(contentid bigint,sourcerevisionid bigint) LANGUAGE plpgsql AS $$
DECLARE v_revision bigint;v_no integer;v_content bigint;
BEGIN
 IF p_kind NOT IN ('POST','COMMENT') OR NULLIF(btrim(p_body),'') IS NULL
   OR (p_kind='POST' AND p_parentpostid IS NOT NULL)
   OR (p_kind='COMMENT' AND p_parentpostid IS NULL) THEN
   RAISE EXCEPTION 'Invalid post/comment' USING ERRCODE='22023';
 END IF;
 PERFORM 1 FROM social.community WHERE communityid=p_communityid FOR UPDATE;
 IF NOT auth.can_write_community(p_authoruserid,p_communityid) THEN
   RAISE EXCEPTION 'Publishing forbidden' USING ERRCODE='42501';
 END IF;
 IF p_kind='COMMENT' AND NOT EXISTS (
   SELECT 1 FROM social.accessible_content(p_authoruserid) a WHERE a.contentid=p_parentpostid
     AND a.communityid=p_communityid AND a.kind='POST') THEN
   RAISE EXCEPTION 'Parent post unavailable' USING ERRCODE='P0002';
 END IF;
 IF p_contentid IS NULL THEN
   INSERT INTO social.contentitem(kind,contentstatus,allowrag,publishedat)
   VALUES (p_kind,'PUBLISHED',true,now()) RETURNING social.contentitem.contentid INTO v_content;
   INSERT INTO social.authored(userid,contentid) VALUES(p_authoruserid,v_content);
   IF p_kind='POST' THEN
     INSERT INTO social.publishedin(contentid,communityid) VALUES(v_content,p_communityid);
   ELSE
     INSERT INTO social.commenton(commentcontentid,postcontentid) VALUES(v_content,p_parentpostid);
   END IF;
   v_no:=1;
 ELSE
   v_content:=p_contentid;
   PERFORM 1 FROM social.contentitem WHERE contentid=v_content FOR UPDATE;
   IF NOT EXISTS (SELECT 1 FROM social.accessible_content(p_authoruserid) a
      WHERE a.contentid=v_content AND a.communityid=p_communityid AND a.kind=p_kind AND a.authoruserid=p_authoruserid) THEN
      RAISE EXCEPTION 'Only the author can edit accessible content' USING ERRCODE='42501';
   END IF;
   SELECT CASE WHEN p_kind='POST' THEN (SELECT coalesce(max(revisionno),0)+1 FROM social.postrevision WHERE social.postrevision.contentid=v_content)
     ELSE (SELECT coalesce(max(revisionno),0)+1 FROM social.commentrevision WHERE social.commentrevision.contentid=v_content) END INTO v_no;
   UPDATE social.postrevision SET iscurrent=false WHERE social.postrevision.contentid=v_content AND iscurrent;
   UPDATE social.commentrevision SET iscurrent=false WHERE social.commentrevision.contentid=v_content AND iscurrent;
   UPDATE knowledge.sourcerevision SET iscurrent=false WHERE knowledge.sourcerevision.contentid=v_content AND iscurrent;
   UPDATE social.contentitem SET updatedat=now() WHERE social.contentitem.contentid=v_content;
 END IF;
 IF p_kind='POST' THEN
   INSERT INTO social.postrevision(contentid,revisionno,body,contenthash,editedbyuserid)
   VALUES(v_content,v_no,p_body,digest(p_body,'sha256'),p_authoruserid)
   RETURNING revisionid INTO v_revision;
   INSERT INTO knowledge.sourcerevision(contentid,postrevisionid,extractedtext,texthash)
   VALUES(v_content,v_revision,p_body,digest(p_body,'sha256')) RETURNING knowledge.sourcerevision.sourcerevisionid INTO sourcerevisionid;
 ELSE
   INSERT INTO social.commentrevision(contentid,revisionno,body)
   VALUES(v_content,v_no,p_body) RETURNING revisionid INTO v_revision;
   INSERT INTO knowledge.sourcerevision(contentid,commentrevisionid,extractedtext,texthash)
   VALUES(v_content,v_revision,p_body,digest(p_body,'sha256')) RETURNING knowledge.sourcerevision.sourcerevisionid INTO sourcerevisionid;
 END IF;
 INSERT INTO ops.auditevent(actoruserid,eventtype,entitytype,entityid)
 VALUES (p_authoruserid,'PUBLISH','CONTENT',v_content);
 contentid:=v_content;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION knowledge.usp_savedocumentversion(p_authoruserid bigint,p_communityid bigint,
 p_contentid bigint,p_title text,p_filename text,p_mimetype text,p_filebytes bytea,p_plaintext text)
RETURNS TABLE(contentid bigint,documentversionid bigint,sourcerevisionid bigint)
LANGUAGE plpgsql AS $$
DECLARE v_content bigint;v_no integer;v_size bigint;v_digest bytea;
BEGIN
 PERFORM 1 FROM social.community WHERE communityid=p_communityid FOR UPDATE;
 IF NOT auth.can_write_community(p_authoruserid,p_communityid) THEN RAISE EXCEPTION 'Upload forbidden' USING ERRCODE='42501'; END IF;
 IF p_mimetype NOT IN ('text/plain','application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    OR NULLIF(btrim(p_title),'') IS NULL
    OR (p_mimetype='text/plain' AND (p_plaintext IS NULL OR p_filebytes IS NOT NULL))
    OR (p_mimetype<>'text/plain' AND (p_filebytes IS NULL OR p_plaintext IS NOT NULL OR p_filename IS NULL)) THEN
    RAISE EXCEPTION 'Invalid document payload' USING ERRCODE='22023';
 END IF;
 v_size:=coalesce(octet_length(p_filebytes),octet_length(p_plaintext));
 IF v_size NOT BETWEEN 1 AND 10485760 THEN RAISE EXCEPTION 'Document size out of bounds' USING ERRCODE='22023'; END IF;
 v_digest:=CASE WHEN p_filebytes IS NOT NULL THEN digest(p_filebytes,'sha256') ELSE digest(p_plaintext,'sha256') END;
 IF p_contentid IS NULL THEN
   INSERT INTO social.contentitem(kind,contentstatus,allowrag,publishedat)
   VALUES('DOCUMENT','PUBLISHED',true,now()) RETURNING social.contentitem.contentid INTO v_content;
   INSERT INTO social.documentdetail(contentid,title) VALUES(v_content,p_title);
   INSERT INTO social.authored(userid,contentid) VALUES(p_authoruserid,v_content);
   INSERT INTO social.publishedin(contentid,communityid) VALUES(v_content,p_communityid);
   v_no:=1;
 ELSE
   v_content:=p_contentid;
   PERFORM 1 FROM social.contentitem WHERE social.contentitem.contentid=v_content FOR UPDATE;
   IF NOT EXISTS (SELECT 1 FROM social.accessible_content(p_authoruserid) a WHERE a.contentid=v_content
      AND a.kind='DOCUMENT' AND a.communityid=p_communityid AND a.authoruserid=p_authoruserid) THEN
     RAISE EXCEPTION 'Document unavailable or not authored by user' USING ERRCODE='42501';
   END IF;
   SELECT coalesce(max(versionno),0)+1 INTO v_no FROM knowledge.documentversion WHERE knowledge.documentversion.contentid=v_content;
   UPDATE knowledge.documentversion SET iscurrent=false WHERE knowledge.documentversion.contentid=v_content AND iscurrent;
   UPDATE knowledge.sourcerevision SET iscurrent=false WHERE knowledge.sourcerevision.contentid=v_content AND iscurrent;
   UPDATE social.documentdetail SET title=p_title,documentstatus='PROCESSING' WHERE social.documentdetail.contentid=v_content;
 END IF;
 INSERT INTO knowledge.documentversion(contentid,versionno,filename,mimetype,filebytes,plaintext,sizebytes,sha256)
 VALUES(v_content,v_no,p_filename,p_mimetype,p_filebytes,p_plaintext,v_size,v_digest)
 RETURNING knowledge.documentversion.documentversionid INTO documentversionid;
 INSERT INTO knowledge.sourcerevision(contentid,documentversionid)
 VALUES(v_content,documentversionid)
 RETURNING knowledge.sourcerevision.sourcerevisionid INTO sourcerevisionid;
 INSERT INTO ops.auditevent(actoruserid,eventtype,entitytype,entityid)
 VALUES (p_authoruserid,'UPLOAD','DOCUMENT',v_content);
 contentid:=v_content;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION social.usp_moderatecontent(p_actoruserid bigint,p_contentid bigint)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_community bigint;
BEGIN
 SELECT a.communityid INTO v_community FROM social.accessible_content(p_actoruserid) a WHERE a.contentid=p_contentid;
 IF v_community IS NULL THEN RAISE EXCEPTION 'Content unavailable' USING ERRCODE='P0002'; END IF;
 IF NOT EXISTS (SELECT 1 FROM social.community c WHERE c.communityid=v_community AND c.owneruserid=p_actoruserid)
   AND NOT EXISTS (SELECT 1 FROM social.memberof m WHERE m.communityid=v_community AND m.userid=p_actoruserid
     AND m.memberstatus='ACTIVE' AND m.role IN ('ADMIN','MODERATOR') AND m.endedat IS NULL) THEN
   RAISE EXCEPTION 'Moderation forbidden' USING ERRCODE='42501';
 END IF;
 UPDATE social.contentitem SET contentstatus='HIDDEN',allowrag=false,updatedat=now()
 WHERE social.contentitem.contentid=p_contentid OR social.contentitem.contentid IN
   (SELECT commentcontentid FROM social.commenton WHERE postcontentid=p_contentid);
 INSERT INTO ops.auditevent(actoruserid,eventtype,entitytype,entityid)
 VALUES (p_actoruserid,'MODERATE','CONTENT',p_contentid);
 RETURN true;
END;
$$;
