-- Free public deployment can answer questions without a continuously running
-- query-embedding service. SQL Server and the PostgreSQL hybrid function retain
-- vector search; this additional PostgreSQL entry point uses Russian FTS and
-- evidence-backed graph expansion with the same live source ACL.
CREATE OR REPLACE FUNCTION assistant.usp_startragturn(p_sessionid bigint,p_userid bigint,
 p_question text,p_modelversion text)
RETURNS TABLE(turnid bigint,retrievalrunid bigint,turnno integer,communityid bigint)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $$
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
 INSERT INTO assistant.retrievalrun(turnid,modelversion,retrievalmode)
 VALUES(v_turn,p_modelversion,CASE WHEN p_modelversion='postgres-lexical-rag-v1'
   THEN 'FULLTEXT' ELSE 'HYBRID_GRAPH' END)
 RETURNING assistant.retrievalrun.retrievalrunid INTO v_run;
 turnid:=v_turn;retrievalrunid:=v_run;turnno:=v_turnno;communityid:=v_community;RETURN NEXT;
END;
$$;
REVOKE ALL ON FUNCTION assistant.usp_startragturn(bigint,bigint,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION assistant.usp_startragturn(bigint,bigint,text,text) TO coursework_api;

CREATE OR REPLACE FUNCTION assistant.usp_searchraglexical(
 p_userid bigint,p_question text,p_topk integer,p_queryentitiesjson text,p_communityid bigint)
RETURNS TABLE(chunkid bigint,contentid bigint,kind text,chunktext text,pageno integer,
 startoffset integer,endoffset integer,title text,authoruserid bigint,communityid bigint,
 rank bigint,vectorscore double precision,textscore double precision,graphscore double precision)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $$
DECLARE v_entities jsonb;
BEGIN
 IF p_topk NOT BETWEEN 1 AND 20 OR NULLIF(btrim(p_question),'') IS NULL THEN
   RAISE EXCEPTION 'Invalid RAG search settings' USING ERRCODE='22023';
 END IF;
 IF p_communityid IS NOT NULL AND NOT auth.can_read_community(p_userid,p_communityid) THEN
   RAISE EXCEPTION 'Community unavailable' USING ERRCODE='P0002';
 END IF;
 v_entities:=p_queryentitiesjson::jsonb;
 IF jsonb_typeof(v_entities)<>'array' THEN
   RAISE EXCEPTION 'Entity names must be an array' USING ERRCODE='22023';
 END IF;
 RETURN QUERY
 WITH names AS (SELECT lower(value) AS name FROM jsonb_array_elements_text(v_entities)),
 allowed AS (
   SELECT ch.chunkid,ch.contentid,ch.kind::text,ch.chunktext,ch.pageno,ch.startoffset,ch.endoffset,
     ch.title,ch.authoruserid,ch.communityid,
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
   WHERE p_communityid IS NULL OR ch.communityid=p_communityid
 ), ranked AS (
   SELECT a.*,row_number() OVER (ORDER BY (0.7*a.ts+0.3*a.gs) DESC,a.chunkid) AS ordinal
   FROM allowed a WHERE a.ts>0 OR a.gs>0
 )
 SELECT r.chunkid,r.contentid,r.kind,r.chunktext,r.pageno,r.startoffset,r.endoffset,r.title,
   r.authoruserid,r.communityid,r.ordinal,0.0::double precision,r.ts,r.gs FROM ranked r
 WHERE r.ordinal<=p_topk ORDER BY r.ordinal;
END;
$$;

REVOKE ALL ON FUNCTION assistant.usp_searchraglexical(bigint,text,integer,text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION assistant.usp_searchraglexical(bigint,text,integer,text,bigint) TO coursework_api;
