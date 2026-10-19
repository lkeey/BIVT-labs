-- Rule-based personalized feed; every candidate and graph signal is ACL-filtered.
CREATE OR REPLACE FUNCTION assistant.usp_generaterecommendations(p_userid bigint,p_limit integer DEFAULT 20)
RETURNS TABLE(rank integer,contentid bigint,kind text,score double precision,reasoncode text,
 reasontext text,communityid bigint,authoruserid bigint)
LANGUAGE plpgsql AS $$
DECLARE v_batch bigint;
BEGIN
 IF p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'Invalid feed limit' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount WHERE userid=p_userid AND accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active user required' USING ERRCODE='42501';
 END IF;
 INSERT INTO assistant.recommendationbatch(userid,algorithmversion)
 VALUES(p_userid,'rule-v1') RETURNING assistant.recommendationbatch.batchid INTO v_batch;
 WITH interested_content AS (
   SELECT r.contentid FROM social.reactto r WHERE r.userid=p_userid
   UNION
   SELECT co.postcontentid FROM social.commenton co JOIN social.authored a ON a.contentid=co.commentcontentid
     WHERE a.userid=p_userid
 ), visible_interest AS (
   SELECT DISTINCT a.contentid,a.communityid FROM interested_content ic
     JOIN social.accessible_content(p_userid) a ON a.contentid=ic.contentid
 ), interest_entity AS (
   SELECT DISTINCT lower(e.entityname) AS entityname
   FROM visible_interest vi JOIN knowledge.accessible_chunks(p_userid) ch ON ch.contentid=vi.contentid
   JOIN knowledge.mentions m ON m.evidencechunkid=ch.chunkid
   JOIN knowledge.knowledgeentity e ON e.entityid=m.entityid
 ), candidate_entity AS (
   SELECT DISTINCT ch.contentid,lower(e.entityname) AS entityname
   FROM knowledge.accessible_chunks(p_userid) ch JOIN knowledge.mentions m ON m.evidencechunkid=ch.chunkid
   JOIN knowledge.knowledgeentity e ON e.entityid=m.entityid
 ), candidate_topic AS (
   SELECT ce.contentid,CASE WHEN count(ie.entityname)>0 THEN 1.0 ELSE 0.0 END AS topicscore
   FROM candidate_entity ce LEFT JOIN interest_entity ie ON ie.entityname=ce.entityname
   GROUP BY ce.contentid
 ), popularity AS (
   SELECT react.contentid,least(1.0,count(*)/5.0) AS popularscore
   FROM social.reactto react GROUP BY react.contentid
 ), signals AS (
   SELECT a.contentid,a.communityid,a.authoruserid,coalesce(ct.topicscore,0.0) AS topicscore,
     CASE WHEN f.followeduserid IS NULL THEN 0.0 ELSE 1.0 END AS followscore,
     CASE WHEN c.owneruserid=p_userid OR EXISTS (SELECT 1 FROM social.memberof m
       WHERE m.userid=p_userid AND m.communityid=a.communityid AND m.memberstatus='ACTIVE' AND m.endedat IS NULL)
       THEN 1.0 ELSE 0.0 END AS memberscore,
     CASE WHEN EXISTS (SELECT 1 FROM visible_interest vi WHERE vi.communityid=a.communityid)
       THEN 1.0 ELSE 0.0 END AS interestscore,
     CASE WHEN a.publishedat>=now()-interval '1 day' THEN 1.0
       WHEN a.publishedat>=now()-interval '7 days' THEN 0.7
       WHEN a.publishedat>=now()-interval '30 days' THEN 0.3 ELSE 0.1 END AS freshscore,
     coalesce(p.popularscore,0.0) AS popularscore
   FROM social.accessible_content(p_userid) a JOIN social.community c ON c.communityid=a.communityid
   LEFT JOIN social.follows f ON f.followeruserid=p_userid AND f.followeduserid=a.authoruserid
   LEFT JOIN candidate_topic ct ON ct.contentid=a.contentid
   LEFT JOIN popularity p ON p.contentid=a.contentid
   WHERE a.kind IN ('POST','DOCUMENT') AND a.authoruserid<>p_userid
 ), scored AS (
   SELECT s.*,
     CASE WHEN EXISTS (SELECT 1 FROM visible_interest)
       OR EXISTS (SELECT 1 FROM social.follows f WHERE f.followeruserid=p_userid)
       OR EXISTS (SELECT 1 FROM social.memberof m WHERE m.userid=p_userid AND m.memberstatus='ACTIVE' AND m.endedat IS NULL)
     THEN (0.30*s.topicscore+0.25*s.followscore+0.20*s.memberscore+0.15*s.interestscore+0.10*s.freshscore)
     ELSE (0.60*s.freshscore+0.40*s.popularscore) END AS totalscore
   FROM signals s
 ), diverse AS (
   SELECT s.*,row_number() OVER(PARTITION BY s.authoruserid ORDER BY s.totalscore DESC,s.contentid) AS authorordinal,
     row_number() OVER(PARTITION BY s.communityid ORDER BY s.totalscore DESC,s.contentid) AS communityordinal
   FROM scored s
 ), top_items AS (
   SELECT d.* FROM diverse d WHERE d.authorordinal<=2 AND d.communityordinal<=3
   ORDER BY d.totalscore DESC,d.contentid LIMIT p_limit
 ), ranked AS (
   SELECT t.*,row_number() OVER(ORDER BY t.totalscore DESC,t.contentid)::integer AS itemrank FROM top_items t
 )
 INSERT INTO assistant.recommendationitem(batchid,contentid,rank,score,reasoncode,reasontext)
 SELECT v_batch,r.contentid,r.itemrank,r.totalscore::numeric(9,6),
   CASE WHEN r.topicscore>0 THEN 'RELATED_TOPIC'
     WHEN r.followscore>0 THEN 'FOLLOWED_AUTHOR'
     WHEN r.memberscore>0 THEN 'MEMBER_COMMUNITY'
     WHEN r.interestscore>0 THEN 'SIMILAR_INTEREST'
     WHEN r.popularscore>0 THEN 'POPULAR' ELSE 'FRESH' END,
   CASE WHEN r.topicscore>0 THEN 'Похоже на интересующие вас темы'
     WHEN r.followscore>0 THEN 'Автор, на которого вы подписаны'
     WHEN r.memberscore>0 THEN 'Из вашего сообщества'
     WHEN r.interestscore>0 THEN 'Похоже на материалы, с которыми вы взаимодействовали'
     WHEN r.popularscore>0 THEN 'Популярно в доступных вам сообществах'
     ELSE 'Недавно опубликовано' END
 FROM ranked r;
 RETURN QUERY
 SELECT ri.rank,ri.contentid,a.kind::text,ri.score::double precision,ri.reasoncode::text,
   ri.reasontext::text,a.communityid,a.authoruserid
 FROM assistant.recommendationitem ri JOIN social.accessible_content(p_userid) a ON a.contentid=ri.contentid
 WHERE ri.batchid=v_batch AND a.kind IN ('POST','DOCUMENT') ORDER BY ri.rank;
END;
$$;
