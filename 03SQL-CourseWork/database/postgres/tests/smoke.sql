-- Dedicated test database only. Every test row is rolled back.
\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE owner_id bigint; member_id bigint; stranger_id bigint; community_id bigint;
 post_id bigint; comment_id bigint; doc_id bigint; old_version bigint; new_version bigint;
 public_id bigint; public_post bigint; binary_id bigint; result record;
BEGIN
 SELECT userid INTO owner_id FROM auth.usp_getorcreatefirebaseuser('smoke-owner');
 SELECT userid INTO member_id FROM auth.usp_getorcreatefirebaseuser('smoke-member');
 SELECT userid INTO stranger_id FROM auth.usp_getorcreatefirebaseuser('smoke-stranger');
 SELECT communityid INTO community_id FROM social.usp_createcommunity(owner_id,'smoke-private','Private','PRIVATE');
 SELECT communityid INTO public_id FROM social.usp_createcommunity(owner_id,'smoke-public','Public','PUBLIC');
 PERFORM social.usp_requestmembership(member_id,community_id);
 IF auth.can_read_community(member_id,community_id) THEN RAISE EXCEPTION 'Pending member can read private community'; END IF;
 PERFORM social.usp_setmembership(owner_id,community_id,member_id,'ACTIVE');
 SELECT contentid INTO post_id FROM social.usp_publishcontent(owner_id,community_id,'POST','First post');
 SELECT contentid INTO public_post FROM social.usp_publishcontent(owner_id,public_id,'POST','Public post');
 PERFORM social.usp_publishcontent(owner_id,community_id,'POST','Edited post',NULL,post_id);
 IF (SELECT count(*) FROM social.postrevision WHERE contentid=post_id)<>2 THEN RAISE EXCEPTION 'Post history lost'; END IF;
 IF (SELECT body FROM social.usp_getpost(member_id,post_id))<>'Edited post' THEN RAISE EXCEPTION 'Current post mismatch'; END IF;
 SELECT contentid INTO comment_id FROM social.usp_publishcontent(member_id,community_id,'COMMENT','Comment',post_id);
 PERFORM social.usp_setreaction(member_id,post_id,'LIKE');
 SELECT contentid,documentversionid INTO doc_id,old_version FROM social.usp_savedocumentversion(
   owner_id,community_id,NULL,'Document',NULL,'text/plain',NULL,'Version one');
 SELECT documentversionid INTO new_version FROM social.usp_savedocumentversion(
   owner_id,community_id,doc_id,'Document',NULL,'text/plain',NULL,'Version two');
 IF old_version=new_version OR (SELECT count(*) FROM social.documentversion WHERE contentid=doc_id)<>2 THEN
   RAISE EXCEPTION 'Document history lost'; END IF;
 IF (SELECT plaintext FROM social.usp_getdocumentfile(member_id,doc_id))<>'Version two' THEN RAISE EXCEPTION 'Document read mismatch'; END IF;
 SELECT contentid INTO binary_id FROM social.usp_savedocumentversion(
   owner_id,community_id,NULL,'PDF','example.pdf','application/pdf',decode('255044462d312e37','hex'),NULL);
 IF (SELECT filebytes FROM social.usp_getdocumentfile(member_id,binary_id))<>decode('255044462d312e37','hex') THEN
   RAISE EXCEPTION 'Binary document bytes changed'; END IF;
 BEGIN
   PERFORM social.usp_publishcontent(member_id,community_id,'POST','Unauthorized edit',NULL,post_id);
   RAISE EXCEPTION 'Non-author edited post';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 IF EXISTS(SELECT 1 FROM social.usp_getpost(stranger_id,post_id)) OR EXISTS(SELECT 1 FROM social.usp_getdocumentfile(stranger_id,doc_id)) THEN
   RAISE EXCEPTION 'Private content leaked'; END IF;
 PERFORM social.usp_setfollow(member_id,owner_id,true);
 IF NOT EXISTS(SELECT 1 FROM social.usp_buildrecommendationfeed(member_id,20) WHERE contentid=post_id AND reasoncode='FOLLOWED_AUTHOR') THEN
   RAISE EXCEPTION 'Follow feed missing'; END IF;
 PERFORM social.usp_setmembership(owner_id,community_id,member_id,'BLOCKED');
 IF EXISTS(SELECT 1 FROM social.usp_getdocumentfile(member_id,doc_id)) OR EXISTS(SELECT 1 FROM social.usp_buildrecommendationfeed(member_id,20) WHERE contentid=post_id) THEN
   RAISE EXCEPTION 'Revoked access leaked'; END IF;
 PERFORM social.usp_moderatecontent(owner_id,post_id);
 IF EXISTS(SELECT 1 FROM social.usp_getcomment(owner_id,comment_id)) THEN RAISE EXCEPTION 'Hidden parent leaked comment'; END IF;
 IF has_table_privilege('coursework_api','social.documentversion','SELECT') THEN RAISE EXCEPTION 'API role has direct table reads'; END IF;
 IF NOT has_function_privilege('coursework_api','social.usp_getdocumentfile(bigint,bigint)','EXECUTE') THEN RAISE EXCEPTION 'API function grant missing'; END IF;
END $$;
SET LOCAL ROLE coursework_api;
SELECT * FROM auth.usp_getorcreatefirebaseuser('smoke-api-role');
RESET ROLE;
ROLLBACK;
