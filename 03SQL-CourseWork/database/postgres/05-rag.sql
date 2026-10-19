CREATE OR REPLACE FUNCTION assistant.usp_startragsession(p_userid bigint,p_communityid bigint DEFAULT NULL)
RETURNS TABLE(sessionid bigint) LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount WHERE userid=p_userid AND accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active user required' USING ERRCODE='42501';
 END IF;
 IF p_communityid IS NOT NULL AND NOT auth.can_read_community(p_userid,p_communityid) THEN
   RAISE EXCEPTION 'Community unavailable' USING ERRCODE='P0002';
 END IF;
 INSERT INTO assistant.ragsession(userid,scope,communityid)
 VALUES(p_userid,CASE WHEN p_communityid IS NULL THEN 'AllAccessible' ELSE 'Community' END,p_communityid)
 RETURNING assistant.ragsession.sessionid INTO sessionid;
 RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_startragturn(p_sessionid bigint,p_userid bigint,
 p_question text,p_modelversion text)
RETURNS TABLE(turnid bigint,retrievalrunid bigint,turnno integer,communityid bigint)
LANGUAGE plpgsql AS $$
DECLARE v_owner bigint;v_community bigint;v_turnno integer;v_turn bigint;v_run bigint;
BEGIN
 IF NULLIF(btrim(p_question),'') IS NULL OR length(p_question)>2000 OR NULLIF(btrim(p_modelversion),'') IS NULL THEN
   RAISE EXCEPTION 'Invalid RAG question or model' USING ERRCODE='22023';
 END IF;
 SELECT s.userid,s.communityid INTO v_owner,v_community FROM assistant.ragsession s
 WHERE s.sessionid=p_sessionid FOR UPDATE;
 IF v_owner IS NULL OR v_owner<>p_userid OR
   NOT EXISTS (SELECT 1 FROM auth.useraccount u WHERE u.userid=p_userid AND u.accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'RAG session unavailable' USING ERRCODE='P0002';
 END IF;
 IF v_community IS NOT NULL AND NOT auth.can_read_community(p_userid,v_community) THEN
   RAISE EXCEPTION 'RAG community unavailable' USING ERRCODE='P0002';
 END IF;
 SELECT coalesce(max(t.turnno),0)+1 INTO v_turnno FROM assistant.ragturn t WHERE t.sessionid=p_sessionid;
 INSERT INTO assistant.ragturn(sessionid,turnno,questiontext) VALUES(p_sessionid,v_turnno,p_question)
 RETURNING assistant.ragturn.turnid INTO v_turn;
 INSERT INTO assistant.retrievalrun(turnid,modelversion) VALUES(v_turn,p_modelversion)
 RETURNING assistant.retrievalrun.retrievalrunid INTO v_run;
 turnid:=v_turn;retrievalrunid:=v_run;turnno:=v_turnno;communityid:=v_community;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_failragturn(p_turnid bigint,p_retrievalrunid bigint)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
 IF p_retrievalrunid IS NOT NULL AND NOT EXISTS (
   SELECT 1 FROM assistant.retrievalrun WHERE retrievalrunid=p_retrievalrunid AND turnid=p_turnid) THEN
   RAISE EXCEPTION 'Retrieval run does not belong to turn' USING ERRCODE='P0002';
 END IF;
 UPDATE assistant.ragturn SET generationstatus='FAILED',completedat=now()
 WHERE turnid=p_turnid AND generationstatus='PENDING';
 IF NOT FOUND THEN RAISE EXCEPTION 'Pending turn unavailable' USING ERRCODE='P0002'; END IF;
 RETURN true;
END;
$$;

-- Exact cosine distance on pgvector, Russian FTS, and evidence-backed graph expansion.
CREATE OR REPLACE FUNCTION assistant.usp_searchrag(p_userid bigint,p_question text,p_queryembedding text,
 p_topk integer,p_queryentitiesjson text,p_communityid bigint)
RETURNS TABLE(chunkid bigint,contentid bigint,kind text,chunktext text,pageno integer,
 startoffset integer,endoffset integer,title text,authoruserid bigint,communityid bigint,
 rank bigint,vectorscore double precision,textscore double precision,graphscore double precision)
LANGUAGE plpgsql STABLE AS $$
DECLARE v_query vector(384);v_entities jsonb;
BEGIN
 IF p_topk NOT BETWEEN 1 AND 20 OR NULLIF(btrim(p_question),'') IS NULL THEN
   RAISE EXCEPTION 'Invalid RAG search settings' USING ERRCODE='22023';
 END IF;
 IF p_communityid IS NOT NULL AND NOT auth.can_read_community(p_userid,p_communityid) THEN
   RAISE EXCEPTION 'Community unavailable' USING ERRCODE='P0002';
 END IF;
 IF jsonb_typeof(p_queryembedding::jsonb)<>'array'
    OR jsonb_array_length(p_queryembedding::jsonb)<>384
    OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p_queryembedding::jsonb) element
      WHERE jsonb_typeof(element.value)='number' AND (element.value)::text::numeric<>0) THEN
   RAISE EXCEPTION 'Query embedding must be a nonzero 384D vector' USING ERRCODE='22023';
 END IF;
 v_query:=p_queryembedding::vector(384);
 v_entities:=p_queryentitiesjson::jsonb;
 IF jsonb_typeof(v_entities)<>'array' THEN RAISE EXCEPTION 'Entity names must be an array' USING ERRCODE='22023'; END IF;
 RETURN QUERY
 WITH names AS (SELECT lower(value) AS name FROM jsonb_array_elements_text(v_entities)),
 allowed AS (
   SELECT ch.chunkid,ch.contentid,ch.kind::text,ch.chunktext,ch.pageno,ch.startoffset,ch.endoffset,
     ch.title,ch.authoruserid,ch.communityid,
     (1.0-(e.embedding <=> v_query))::double precision AS vs,
     CASE WHEN to_tsvector('russian',ch.chunktext) @@ plainto_tsquery('russian',p_question)
       THEN LEAST(1.0,ts_rank_cd(to_tsvector('russian',ch.chunktext),plainto_tsquery('russian',p_question)))
       ELSE 0.0 END::double precision AS ts,
     greatest(coalesce((
       SELECT max(m.confidence)::double precision FROM knowledge.mentions m
       JOIN knowledge.knowledgeentity ent ON ent.entityid=m.entityid
       WHERE m.evidencechunkid=ch.chunkid AND EXISTS (SELECT 1 FROM names n WHERE n.name=lower(ent.entityname))
     ),0),coalesce((
       SELECT max(0.5*r.confidence*m.confidence)::double precision
       FROM knowledge.entityrelation r
       JOIN knowledge.knowledgeentity origin ON origin.entityid=r.fromentityid
       JOIN knowledge.mentions m ON m.entityid=r.toentityid AND m.evidencechunkid=ch.chunkid
       JOIN knowledge.accessible_chunks(p_userid) evidence ON evidence.chunkid=r.evidencechunkid
       WHERE EXISTS (SELECT 1 FROM names n WHERE n.name=lower(origin.entityname))
         AND (p_communityid IS NULL OR evidence.communityid=p_communityid)
     ),0)) AS gs
   FROM knowledge.accessible_chunks(p_userid) ch
   JOIN knowledge.chunkembedding e ON e.chunkid=ch.chunkid
   JOIN knowledge.embeddingmodel em ON em.modelid=e.modelid AND em.isactive
      AND em.modelname='intfloat/multilingual-e5-small'
      AND em.modelversion='fd1525a9fd15316a2d503bf26ab031a61d056e98'
   WHERE p_communityid IS NULL OR ch.communityid=p_communityid
 ), ranked AS (
   SELECT a.*,row_number() OVER (ORDER BY (0.55*a.vs+0.30*a.ts+0.15*a.gs) DESC,a.chunkid) AS ordinal
   FROM allowed a
 )
 SELECT r.chunkid,r.contentid,r.kind,r.chunktext,r.pageno,r.startoffset,r.endoffset,r.title,
   r.authoruserid,r.communityid,r.ordinal,r.vs,r.ts,r.gs FROM ranked r
 WHERE r.ordinal<=p_topk ORDER BY r.ordinal;
END;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_recordretrievedchunks(p_retrievalrunid bigint,p_userid bigint,
 p_chunksjson text)
RETURNS TABLE(retrievalrunid bigint,recordedchunkcount integer) LANGUAGE plpgsql AS $$
DECLARE v_input jsonb;v_count integer;v_scope bigint;v_owner bigint;v_status varchar;v_inserted integer;
BEGIN
 v_input:=p_chunksjson::jsonb;
 IF jsonb_typeof(v_input)<>'array' THEN RAISE EXCEPTION 'Retrieved chunks must be an array' USING ERRCODE='22023'; END IF;
 v_count:=jsonb_array_length(v_input);
 IF v_count NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Invalid retrieved chunk count' USING ERRCODE='22023'; END IF;
 SELECT s.userid,s.communityid,t.generationstatus INTO v_owner,v_scope,v_status
 FROM assistant.retrievalrun rr JOIN assistant.ragturn t ON t.turnid=rr.turnid
 JOIN assistant.ragsession s ON s.sessionid=t.sessionid
 WHERE rr.retrievalrunid=p_retrievalrunid FOR UPDATE OF rr,t;
 IF v_owner IS NULL OR v_owner<>p_userid OR v_status<>'PENDING' THEN
   RAISE EXCEPTION 'Pending retrieval unavailable' USING ERRCODE='P0002';
 END IF;
 IF v_scope IS NOT NULL AND NOT auth.can_read_community(p_userid,v_scope) THEN
   RAISE EXCEPTION 'RAG scope revoked' USING ERRCODE='42501';
 END IF;
 IF EXISTS (SELECT 1 FROM assistant.retrievedchunk WHERE assistant.retrievedchunk.retrievalrunid=p_retrievalrunid) THEN
   RAISE EXCEPTION 'Retrieved chunks already recorded' USING ERRCODE='23505';
 END IF;
 IF (SELECT count(DISTINCT (x->>'chunk_id')::bigint) FROM jsonb_array_elements(v_input) x)<>v_count
   OR (SELECT count(DISTINCT (x->>'rank')::integer) FROM jsonb_array_elements(v_input) x)<>v_count
   OR (SELECT min((x->>'rank')::integer) FROM jsonb_array_elements(v_input) x)<>1
   OR (SELECT max((x->>'rank')::integer) FROM jsonb_array_elements(v_input) x)<>v_count THEN
   RAISE EXCEPTION 'Retrieved chunks must have unique IDs and consecutive ranks' USING ERRCODE='22023';
 END IF;
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_input) x
   WHERE (x->>'vector_score')::numeric NOT BETWEEN -1 AND 1
      OR (x->>'text_score')::numeric NOT BETWEEN 0 AND 1
      OR (x->>'graph_score')::numeric NOT BETWEEN 0 AND 1
      OR x->>'vector_score' IS NULL OR x->>'text_score' IS NULL OR x->>'graph_score' IS NULL) THEN
   RAISE EXCEPTION 'Retrieved chunk score out of range' USING ERRCODE='22023';
 END IF;
 INSERT INTO assistant.retrievedchunk(retrievalrunid,chunkid,rank,vectorscore,textscore,graphscore,snippet)
 SELECT p_retrievalrunid,ch.chunkid,(x->>'rank')::integer,
   (x->>'vector_score')::numeric,(x->>'text_score')::numeric,(x->>'graph_score')::numeric,
   left(ch.chunktext,1000)
 FROM jsonb_array_elements(v_input) x
 JOIN knowledge.accessible_chunks(p_userid) ch ON ch.chunkid=(x->>'chunk_id')::bigint
 WHERE v_scope IS NULL OR ch.communityid=v_scope;
 GET DIAGNOSTICS v_inserted=ROW_COUNT;
 IF v_inserted<>v_count THEN RAISE EXCEPTION 'Stale or inaccessible retrieved chunk' USING ERRCODE='42501'; END IF;
 retrievalrunid:=p_retrievalrunid;recordedchunkcount:=v_count;RETURN NEXT;
END;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_saveragnosources(p_turnid bigint,p_retrievalrunid bigint)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM assistant.retrievalrun WHERE retrievalrunid=p_retrievalrunid AND turnid=p_turnid)
   OR EXISTS (SELECT 1 FROM assistant.retrievedchunk WHERE retrievalrunid=p_retrievalrunid) THEN
   RAISE EXCEPTION 'Retrieval run has sources or does not belong to turn' USING ERRCODE='22023';
 END IF;
 UPDATE assistant.ragturn SET answertext='Недостаточно доступных источников для ответа.',
   answermodel=NULL,generationstatus='NO_SOURCES',completedat=now()
 WHERE turnid=p_turnid AND generationstatus='PENDING';
 IF NOT FOUND THEN RAISE EXCEPTION 'Pending turn unavailable' USING ERRCODE='P0002'; END IF;
 RETURN true;
END;
$$;
CREATE OR REPLACE FUNCTION assistant.run_is_accessible(p_userid bigint,p_retrievalrunid bigint)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT NOT EXISTS (
   SELECT 1 FROM assistant.retrievedchunk rc
   WHERE rc.retrievalrunid=p_retrievalrunid
     AND NOT EXISTS (SELECT 1 FROM knowledge.accessible_chunks(p_userid) ch WHERE ch.chunkid=rc.chunkid)
 );
$$;
CREATE OR REPLACE FUNCTION assistant.usp_saveraganswer(p_turnid bigint,p_retrievalrunid bigint,
 p_answertext text,p_answermodel text,p_citationsjson text)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_user bigint;v_status varchar;v_citations jsonb;v_count integer;v_inserted integer;
BEGIN
 v_citations:=p_citationsjson::jsonb;
 IF jsonb_typeof(v_citations)<>'array' OR jsonb_array_length(v_citations)=0
    OR NULLIF(btrim(p_answertext),'') IS NULL OR NULLIF(btrim(p_answermodel),'') IS NULL THEN
   RAISE EXCEPTION 'Completed answer requires text, model and citations' USING ERRCODE='22023';
 END IF;
 SELECT s.userid,t.generationstatus INTO v_user,v_status FROM assistant.ragturn t
 JOIN assistant.ragsession s ON s.sessionid=t.sessionid
 JOIN assistant.retrievalrun rr ON rr.turnid=t.turnid
 WHERE t.turnid=p_turnid AND rr.retrievalrunid=p_retrievalrunid FOR UPDATE OF t;
 IF v_user IS NULL OR v_status<>'PENDING' THEN RAISE EXCEPTION 'Pending RAG turn unavailable' USING ERRCODE='P0002'; END IF;
 IF NOT assistant.run_is_accessible(v_user,p_retrievalrunid) THEN
   RAISE EXCEPTION 'Retrieved source revoked' USING ERRCODE='42501';
 END IF;
 v_count:=jsonb_array_length(v_citations);
 IF (SELECT count(DISTINCT (x->>'chunk_id')::bigint) FROM jsonb_array_elements(v_citations) x)<>v_count THEN
   RAISE EXCEPTION 'Duplicate citation chunk' USING ERRCODE='22023';
 END IF;
 INSERT INTO assistant.answercitation(retrievalrunid,chunkid,quotetext,pageno,startoffset,endoffset)
 SELECT p_retrievalrunid,ch.chunkid,x->>'quote',(x->>'page_no')::integer,
   (x->>'start_offset')::integer,(x->>'end_offset')::integer
 FROM jsonb_array_elements(v_citations) x
 JOIN assistant.retrievedchunk rc ON rc.retrievalrunid=p_retrievalrunid AND rc.chunkid=(x->>'chunk_id')::bigint
 JOIN knowledge.accessible_chunks(v_user) ch ON ch.chunkid=rc.chunkid
 WHERE (x->>'start_offset')::integer>=ch.startoffset
   AND (x->>'end_offset')::integer<=ch.endoffset
   AND (x->>'end_offset')::integer>(x->>'start_offset')::integer
   AND ch.pageno IS NOT DISTINCT FROM (x->>'page_no')::integer
   AND substr(ch.chunktext,(x->>'start_offset')::integer-ch.startoffset+1,
     (x->>'end_offset')::integer-(x->>'start_offset')::integer)=x->>'quote';
 GET DIAGNOSTICS v_inserted=ROW_COUNT;
 IF v_inserted<>v_count THEN RAISE EXCEPTION 'Citation is not in accessible retrieved text' USING ERRCODE='42501'; END IF;
 UPDATE assistant.ragturn SET answertext=p_answertext,answermodel=p_answermodel,
   generationstatus='COMPLETED',completedat=now() WHERE turnid=p_turnid AND generationstatus='PENDING';
 RETURN true;
END;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_getragturn(p_userid bigint,p_turnid bigint)
RETURNS TABLE(turnid bigint,questiontext text,deliverystatus text,answertext text,answermodel text,completedat timestamptz)
LANGUAGE sql STABLE AS $$
 SELECT t.turnid,t.questiontext::text,
   CASE WHEN t.generationstatus='COMPLETED' AND
      (NOT assistant.run_is_accessible(p_userid,rr.retrievalrunid)
       OR NOT EXISTS (SELECT 1 FROM assistant.answercitation ac WHERE ac.retrievalrunid=rr.retrievalrunid)
       OR EXISTS (SELECT 1 FROM assistant.answercitation ac WHERE ac.retrievalrunid=rr.retrievalrunid
           AND NOT EXISTS (SELECT 1 FROM knowledge.accessible_chunks(p_userid) ch WHERE ch.chunkid=ac.chunkid)))
     THEN 'REVOKED' ELSE t.generationstatus END::text AS deliverystatus,
   CASE WHEN t.generationstatus='NO_SOURCES' OR
      (t.generationstatus='COMPLETED' AND assistant.run_is_accessible(p_userid,rr.retrievalrunid)
       AND EXISTS (SELECT 1 FROM assistant.answercitation ac WHERE ac.retrievalrunid=rr.retrievalrunid)
       AND NOT EXISTS (SELECT 1 FROM assistant.answercitation ac WHERE ac.retrievalrunid=rr.retrievalrunid
           AND NOT EXISTS (SELECT 1 FROM knowledge.accessible_chunks(p_userid) ch WHERE ch.chunkid=ac.chunkid)))
     THEN t.answertext ELSE NULL END,
   CASE WHEN t.generationstatus='COMPLETED' AND assistant.run_is_accessible(p_userid,rr.retrievalrunid)
     AND EXISTS (SELECT 1 FROM assistant.answercitation ac WHERE ac.retrievalrunid=rr.retrievalrunid)
     AND NOT EXISTS (SELECT 1 FROM assistant.answercitation ac WHERE ac.retrievalrunid=rr.retrievalrunid
         AND NOT EXISTS (SELECT 1 FROM knowledge.accessible_chunks(p_userid) ch WHERE ch.chunkid=ac.chunkid))
     THEN t.answermodel::text ELSE NULL END,t.completedat
 FROM assistant.ragturn t JOIN assistant.ragsession s ON s.sessionid=t.sessionid
 JOIN assistant.retrievalrun rr ON rr.turnid=t.turnid
 JOIN auth.useraccount u ON u.userid=s.userid AND u.accountstatus='ACTIVE'
 WHERE t.turnid=p_turnid AND s.userid=p_userid;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_getragcitations(p_userid bigint,p_turnid bigint)
RETURNS TABLE(citationid bigint,chunkid bigint,contentid bigint,kind text,title text,authoruserid bigint,
 communityid bigint,quotetext text,pageno integer,startoffset integer,endoffset integer)
LANGUAGE sql STABLE AS $$
 SELECT ac.citationid,ac.chunkid,ch.contentid,ch.kind::text,ch.title,ch.authoruserid,ch.communityid,
   ac.quotetext::text,ac.pageno,ac.startoffset,ac.endoffset
 FROM assistant.answercitation ac JOIN assistant.retrievalrun rr ON rr.retrievalrunid=ac.retrievalrunid
 JOIN assistant.ragturn t ON t.turnid=rr.turnid JOIN assistant.ragsession s ON s.sessionid=t.sessionid
 JOIN knowledge.accessible_chunks(p_userid) ch ON ch.chunkid=ac.chunkid
 WHERE t.turnid=p_turnid AND s.userid=p_userid AND t.generationstatus='COMPLETED'
   AND assistant.run_is_accessible(p_userid,rr.retrievalrunid)
   AND NOT EXISTS (SELECT 1 FROM assistant.answercitation other WHERE other.retrievalrunid=rr.retrievalrunid
       AND NOT EXISTS (SELECT 1 FROM knowledge.accessible_chunks(p_userid) visible WHERE visible.chunkid=other.chunkid))
 ORDER BY ac.citationid;
$$;
CREATE OR REPLACE FUNCTION assistant.usp_revokecontentaccess(p_actoruserid bigint,p_contentid bigint,
 p_newstatus text,p_allowrag boolean,p_expectedkind text)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_kind varchar;
BEGIN
 IF p_newstatus NOT IN ('HIDDEN','DELETED') THEN RAISE EXCEPTION 'Invalid revoked status' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (SELECT 1 FROM auth.useraccount WHERE userid=p_actoruserid AND accountstatus='ACTIVE') THEN
   RAISE EXCEPTION 'Active author required' USING ERRCODE='42501';
 END IF;
 SELECT i.kind INTO v_kind FROM social.contentitem i JOIN social.authored a ON a.contentid=i.contentid
 WHERE i.contentid=p_contentid AND a.userid=p_actoruserid FOR UPDATE OF i;
 IF v_kind IS NULL THEN RAISE EXCEPTION 'Only author can revoke content' USING ERRCODE='42501'; END IF;
 IF p_expectedkind IS NOT NULL AND p_expectedkind<>v_kind THEN RAISE EXCEPTION 'Unexpected content kind' USING ERRCODE='22023'; END IF;
 UPDATE social.contentitem i SET contentstatus=p_newstatus,
   allowrag=CASE WHEN i.contentid=p_contentid THEN p_allowrag ELSE false END,updatedat=now()
 WHERE i.contentid=p_contentid OR (v_kind='POST' AND i.contentid IN
   (SELECT co.commentcontentid FROM social.commenton co WHERE co.postcontentid=p_contentid));
 INSERT INTO ops.auditevent(actoruserid,eventtype,entitytype,entityid)
 VALUES (p_actoruserid,'REVOKE','CONTENT',p_contentid);
 RETURN true;
END;
$$;
