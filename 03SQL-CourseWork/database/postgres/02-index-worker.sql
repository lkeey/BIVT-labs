-- Claim-bound indexing API. Caller uses one transaction per function call.
CREATE OR REPLACE FUNCTION ops.claim_index_outbox(p_batchsize integer DEFAULT 10)
RETURNS TABLE(eventid bigint,sourcerevisionid bigint,operation varchar,modelid integer,claimtoken uuid)
LANGUAGE plpgsql AS $$
BEGIN
 IF p_batchsize NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Invalid batch size' USING ERRCODE='22023'; END IF;
 RETURN QUERY
 WITH picked AS (
   SELECT o.eventid FROM ops.indexoutbox o WHERE o.eventstatus='PENDING'
   ORDER BY o.createdat,o.eventid LIMIT p_batchsize FOR UPDATE SKIP LOCKED
 )
 UPDATE ops.indexoutbox o SET eventstatus='CLAIMED',attemptcount=o.attemptcount+1,
   claimedat=now(),leaseuntil=now()+interval '10 minutes',claimtoken=gen_random_uuid(),lasterror=NULL
 FROM picked WHERE o.eventid=picked.eventid
 RETURNING o.eventid,o.sourcerevisionid,o.operation,o.modelid,o.claimtoken;
END;
$$;
CREATE OR REPLACE FUNCTION ops.get_claimed_index_source(p_eventid bigint,p_claimtoken uuid)
RETURNS TABLE(eventid bigint,sourcerevisionid bigint,modelid integer,operation varchar,
  contentid bigint,kind varchar,iscurrent boolean,contentstatus varchar,allowrag boolean,
  extractedtext text,documentversionid bigint,mimetype varchar,filename varchar,
  filebytes bytea,plaintext text,modelname varchar,modelversion varchar,dimensions integer)
LANGUAGE plpgsql AS $$
BEGIN
 RETURN QUERY SELECT o.eventid,o.sourcerevisionid,o.modelid,o.operation,s.contentid,i.kind,
   s.iscurrent,i.contentstatus,i.allowrag,s.extractedtext,v.documentversionid,v.mimetype,
   v.filename,v.filebytes,v.plaintext,m.modelname,m.modelversion,m.dimensions
 FROM ops.indexoutbox o JOIN knowledge.sourcerevision s ON s.sourcerevisionid=o.sourcerevisionid
 JOIN social.contentitem i ON i.contentid=s.contentid
 LEFT JOIN knowledge.documentversion v ON v.documentversionid=s.documentversionid
 LEFT JOIN knowledge.embeddingmodel m ON m.modelid=o.modelid
 WHERE o.eventid=p_eventid AND o.claimtoken=p_claimtoken AND o.eventstatus='CLAIMED' AND o.leaseuntil>now();
 IF NOT FOUND THEN RAISE EXCEPTION 'Index claim missing or expired' USING ERRCODE='P0002'; END IF;
END;
$$;
CREATE OR REPLACE FUNCTION ops.renew_index_lease(p_eventid bigint,p_claimtoken uuid)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
 UPDATE ops.indexoutbox SET leaseuntil=now()+interval '10 minutes'
 WHERE eventid=p_eventid AND claimtoken=p_claimtoken AND eventstatus='CLAIMED' AND leaseuntil>now();
 IF NOT FOUND THEN RAISE EXCEPTION 'Index claim missing or expired' USING ERRCODE='P0002'; END IF;
 RETURN true;
END;
$$;
CREATE OR REPLACE FUNCTION ops.complete_index_outbox(p_eventid bigint,p_claimtoken uuid,
  p_succeeded boolean,p_errormessage text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_source bigint; v_status varchar;
BEGIN
 UPDATE ops.indexoutbox SET eventstatus=CASE WHEN p_succeeded THEN 'DONE'
     WHEN attemptcount>=3 THEN 'FAILED' ELSE 'PENDING' END,
   processedat=CASE WHEN p_succeeded THEN now() ELSE NULL END,
   leaseuntil=NULL,claimtoken=NULL,
   lasterror=CASE WHEN p_succeeded THEN NULL ELSE left(p_errormessage,2000) END
 WHERE eventid=p_eventid AND eventstatus='CLAIMED' AND claimtoken=p_claimtoken AND leaseuntil>now()
 RETURNING sourcerevisionid,eventstatus INTO v_source,v_status;
 IF NOT FOUND THEN RAISE EXCEPTION 'Index claim missing or expired' USING ERRCODE='P0002'; END IF;
 IF v_status='FAILED' THEN
   UPDATE knowledge.sourcerevision SET processingstatus='FAILED',processedat=now()
   WHERE sourcerevisionid=v_source AND iscurrent;
   UPDATE social.documentdetail d SET documentstatus='FAILED'
   FROM knowledge.sourcerevision s WHERE s.sourcerevisionid=v_source AND s.contentid=d.contentid AND s.iscurrent;
   UPDATE knowledge.documentversion v SET ocrstatus='FAILED'
   FROM knowledge.sourcerevision s WHERE s.sourcerevisionid=v_source
     AND s.documentversionid=v.documentversionid AND s.iscurrent AND v.ocrstatus='PENDING';
 END IF;
 RETURN true;
END;
$$;
CREATE OR REPLACE FUNCTION ops.requeue_expired_index_outbox(p_batchsize integer DEFAULT 10)
RETURNS TABLE(eventid bigint,eventstatus varchar) LANGUAGE plpgsql AS $$
DECLARE v_event record;
BEGIN
 IF p_batchsize NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Invalid batch size' USING ERRCODE='22023'; END IF;
 FOR v_event IN
  SELECT o.eventid,o.sourcerevisionid,o.attemptcount FROM ops.indexoutbox o
  WHERE o.eventstatus='CLAIMED' AND o.leaseuntil<now()
  ORDER BY o.leaseuntil,o.eventid LIMIT p_batchsize FOR UPDATE SKIP LOCKED
 LOOP
   UPDATE ops.indexoutbox o SET eventstatus=CASE WHEN v_event.attemptcount>=3 THEN 'FAILED' ELSE 'PENDING' END,
     claimedat=NULL,leaseuntil=NULL,claimtoken=NULL,lasterror='Worker lease expired.'
   WHERE o.eventid=v_event.eventid;
   IF v_event.attemptcount>=3 THEN
     UPDATE knowledge.sourcerevision SET processingstatus='FAILED',processedat=now()
     WHERE sourcerevisionid=v_event.sourcerevisionid AND iscurrent;
     UPDATE social.documentdetail d SET documentstatus='FAILED'
     FROM knowledge.sourcerevision s WHERE s.sourcerevisionid=v_event.sourcerevisionid
       AND s.contentid=d.contentid AND s.iscurrent;
     UPDATE knowledge.documentversion v SET ocrstatus='FAILED'
     FROM knowledge.sourcerevision s WHERE s.sourcerevisionid=v_event.sourcerevisionid
       AND s.documentversionid=v.documentversionid AND s.iscurrent AND v.ocrstatus='PENDING';
   END IF;
   eventid:=v_event.eventid;
   eventstatus:=CASE WHEN v_event.attemptcount>=3 THEN 'FAILED' ELSE 'PENDING' END;
   RETURN NEXT;
 END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION ops.reset_source_index(p_sourcerevisionid bigint)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 DELETE FROM knowledge.entityrelation r USING knowledge.chunk c
 WHERE r.evidencechunkid=c.chunkid AND c.sourcerevisionid=p_sourcerevisionid;
 DELETE FROM knowledge.mentions m USING knowledge.chunk c
 WHERE m.evidencechunkid=c.chunkid AND c.sourcerevisionid=p_sourcerevisionid;
 DELETE FROM knowledge.chunkembedding e USING knowledge.chunk c
 WHERE e.chunkid=c.chunkid AND c.sourcerevisionid=p_sourcerevisionid;
 DELETE FROM knowledge.chunkof co USING knowledge.chunk c
 WHERE co.chunkid=c.chunkid AND c.sourcerevisionid=p_sourcerevisionid;
 UPDATE knowledge.chunk SET chunkstatus='STALE' WHERE sourcerevisionid=p_sourcerevisionid;
 DELETE FROM knowledge.chunk c WHERE c.sourcerevisionid=p_sourcerevisionid
   AND NOT EXISTS (SELECT 1 FROM assistant.retrievedchunk rc WHERE rc.chunkid=c.chunkid);
 DELETE FROM knowledge.knowledgeentity e
 WHERE NOT EXISTS (SELECT 1 FROM knowledge.mentions m WHERE m.entityid=e.entityid)
   AND NOT EXISTS (SELECT 1 FROM knowledge.entityrelation r WHERE r.fromentityid=e.entityid OR r.toentityid=e.entityid);
END;
$$;
CREATE OR REPLACE FUNCTION ops.commit_index_deletion(p_eventid bigint,p_claimtoken uuid)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE v_source bigint;
BEGIN
 SELECT sourcerevisionid INTO v_source FROM ops.indexoutbox
 WHERE eventid=p_eventid AND claimtoken=p_claimtoken AND eventstatus='CLAIMED'
   AND operation='DELETE' AND leaseuntil>now() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Deletion claim missing or expired' USING ERRCODE='P0002'; END IF;
 PERFORM ops.reset_source_index(v_source);
 UPDATE ops.indexoutbox SET eventstatus='DONE',processedat=now(),claimtoken=NULL,leaseuntil=NULL,lasterror=NULL
 WHERE eventid=p_eventid AND claimtoken=p_claimtoken;
 RETURN true;
END;
$$;

-- chunks [{chunk_no,text,page_no,start_offset,end_offset,embedding:[384 floats]}]
-- mentions [{local_id,entity_type,entity_name,chunk_no,start_offset,end_offset,evidence_text,confidence,extractor_version}]
-- relations [{from_local_id,to_local_id,predicate_code,chunk_no,start_offset,end_offset,evidence_text,confidence,extractor_version}]
CREATE OR REPLACE FUNCTION ops.commit_index_result(p_eventid bigint,p_claimtoken uuid,p_extractedtext text,
 p_chunks jsonb,p_mentions jsonb DEFAULT '[]'::jsonb,p_relations jsonb DEFAULT '[]'::jsonb,
 p_ocrengineversion text DEFAULT NULL)
RETURNS TABLE(sourcerevisionid bigint,chunkcount integer,entitycount integer)
LANGUAGE plpgsql AS $$
DECLARE v_source bigint; v_content bigint; v_model integer; v_doc bigint;
        c jsonb; m jsonb; r jsonb; v_chunk bigint; v_entity bigint; v_chunkno integer;
        v_chunkmap jsonb:='{}'::jsonb; v_entitymap jsonb:='{}'::jsonb;
        v_mentionsmap jsonb:='{}'::jsonb; v_chunkcount integer:=0; v_entitycount integer:=0;
        v_origin jsonb; v_target jsonb;
BEGIN
 IF p_extractedtext IS NULL OR btrim(p_extractedtext)='' OR p_chunks IS NULL
    OR p_mentions IS NULL OR p_relations IS NULL OR jsonb_typeof(p_chunks)<>'array'
    OR jsonb_typeof(p_mentions)<>'array' OR jsonb_typeof(p_relations)<>'array'
    OR jsonb_array_length(p_chunks)=0 THEN
    RAISE EXCEPTION 'Invalid index payload' USING ERRCODE='22023';
 END IF;
 SELECT o.sourcerevisionid,s.contentid,o.modelid,s.documentversionid
 INTO v_source,v_content,v_model,v_doc
 FROM ops.indexoutbox o JOIN knowledge.sourcerevision s ON s.sourcerevisionid=o.sourcerevisionid
 JOIN social.contentitem i ON i.contentid=s.contentid
 WHERE o.eventid=p_eventid AND o.claimtoken=p_claimtoken AND o.eventstatus='CLAIMED'
   AND o.leaseuntil>now() AND o.operation='UPSERT' AND s.iscurrent
   AND i.contentstatus='PUBLISHED' AND i.allowrag FOR UPDATE OF o,s,i;
 IF v_source IS NULL OR v_model IS NULL THEN
   RAISE EXCEPTION 'Index claim stale or source unavailable' USING ERRCODE='P0002';
 END IF;
 PERFORM ops.reset_source_index(v_source);
 UPDATE knowledge.sourcerevision source SET extractedtext=p_extractedtext,
   texthash=digest(p_extractedtext,'sha256'),processingstatus='PENDING',processedat=NULL
 WHERE source.sourcerevisionid=v_source;
 FOR c IN SELECT value FROM jsonb_array_elements(p_chunks) LOOP
   v_chunkno:=(c->>'chunk_no')::integer;
   IF v_chunkno<1 OR (c->>'start_offset')::integer<0
     OR (c->>'end_offset')::integer<=(c->>'start_offset')::integer
     OR (c->>'end_offset')::integer>length(p_extractedtext)
     OR substr(p_extractedtext,(c->>'start_offset')::integer+1,
       (c->>'end_offset')::integer-(c->>'start_offset')::integer)<>c->>'text'
     OR jsonb_typeof(c->'embedding')<>'array' OR jsonb_array_length(c->'embedding')<>384
     OR EXISTS (SELECT 1 FROM jsonb_array_elements(c->'embedding') element
       WHERE jsonb_typeof(element.value)<>'number')
     OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(c->'embedding') element
       WHERE jsonb_typeof(element.value)='number' AND (element.value)::text::numeric<>0)
     OR v_chunkmap ? v_chunkno::text THEN
     RAISE EXCEPTION 'Invalid chunk text, offsets or embedding' USING ERRCODE='22023';
   END IF;
   INSERT INTO knowledge.chunk(sourcerevisionid,chunkno,chunktext,pageno,startoffset,endoffset,chunkhash)
   VALUES (v_source,v_chunkno,c->>'text',(c->>'page_no')::integer,
      (c->>'start_offset')::integer,(c->>'end_offset')::integer,digest(c->>'text','sha256'))
   RETURNING chunkid INTO v_chunk;
   INSERT INTO knowledge.chunkembedding(chunkid,modelid,embedding)
   VALUES (v_chunk,v_model,(c->'embedding')::text::vector(384));
   INSERT INTO knowledge.chunkof(chunkid,contentid) VALUES (v_chunk,v_content);
   v_chunkmap:=v_chunkmap || jsonb_build_object(v_chunkno::text,v_chunk);
   v_chunkcount:=v_chunkcount+1;
 END LOOP;
 FOR m IN SELECT value FROM jsonb_array_elements(p_mentions) LOOP
   v_chunkno:=(m->>'chunk_no')::integer;
   v_chunk:=(v_chunkmap->>v_chunkno::text)::bigint;
   IF v_chunk IS NULL OR v_entitymap ? (m->>'local_id')
      OR m->>'entity_type' NOT IN ('TOPIC','PERSON','ORGANIZATION','EVENT','PLACE')
      OR btrim(coalesce(m->>'entity_name',''))=''
      OR (m->>'start_offset')::integer<(SELECT startoffset FROM knowledge.chunk WHERE chunkid=v_chunk)
      OR (m->>'end_offset')::integer>(SELECT endoffset FROM knowledge.chunk WHERE chunkid=v_chunk)
      OR substr(p_extractedtext,(m->>'start_offset')::integer+1,
         (m->>'end_offset')::integer-(m->>'start_offset')::integer)<>m->>'evidence_text'
      OR (m->>'confidence')::numeric NOT BETWEEN 0 AND 1 THEN
      RAISE EXCEPTION 'Invalid entity mention evidence' USING ERRCODE='22023';
   END IF;
   INSERT INTO knowledge.knowledgeentity(entitytype,entityname,extractorversion)
   VALUES (m->>'entity_type',m->>'entity_name',m->>'extractor_version')
   RETURNING entityid INTO v_entity;
   INSERT INTO knowledge.mentions(chunkid,entityid,evidencechunkid,startoffset,endoffset,evidencetext,confidence,extractorversion)
   VALUES (v_chunk,v_entity,v_chunk,(m->>'start_offset')::integer,(m->>'end_offset')::integer,
     m->>'evidence_text',(m->>'confidence')::numeric,m->>'extractor_version');
   v_entitymap:=v_entitymap || jsonb_build_object(m->>'local_id',v_entity);
   v_mentionsmap:=v_mentionsmap || jsonb_build_object(m->>'local_id',m);
   v_entitycount:=v_entitycount+1;
 END LOOP;
 FOR r IN SELECT value FROM jsonb_array_elements(p_relations) LOOP
   v_chunkno:=(r->>'chunk_no')::integer;
   v_chunk:=(v_chunkmap->>v_chunkno::text)::bigint;
   v_origin:=v_mentionsmap->(r->>'from_local_id');
   v_target:=v_mentionsmap->(r->>'to_local_id');
   IF v_chunk IS NULL OR v_origin IS NULL OR v_target IS NULL
     OR (v_origin->>'chunk_no')::integer<>v_chunkno OR (v_target->>'chunk_no')::integer<>v_chunkno
     OR r->>'predicate_code' NOT IN ('PARTICIPATES_IN','WORKS_AT','TAKES_PLACE_IN','RELATED_TO')
     OR (r->>'start_offset')::integer>(v_origin->>'start_offset')::integer
     OR (r->>'start_offset')::integer>(v_target->>'start_offset')::integer
     OR (r->>'end_offset')::integer<(v_origin->>'end_offset')::integer
     OR (r->>'end_offset')::integer<(v_target->>'end_offset')::integer
     OR substr(p_extractedtext,(r->>'start_offset')::integer+1,
        (r->>'end_offset')::integer-(r->>'start_offset')::integer)<>r->>'evidence_text'
     OR (r->>'confidence')::numeric NOT BETWEEN 0 AND 1 THEN
     RAISE EXCEPTION 'Invalid relation evidence' USING ERRCODE='22023';
   END IF;
   INSERT INTO knowledge.entityrelation(fromentityid,toentityid,predicatecode,evidencechunkid,
      startoffset,endoffset,evidencetext,confidence,extractorversion)
   VALUES ((v_entitymap->>(r->>'from_local_id'))::bigint,(v_entitymap->>(r->>'to_local_id'))::bigint,
     r->>'predicate_code',v_chunk,(r->>'start_offset')::integer,(r->>'end_offset')::integer,
     r->>'evidence_text',(r->>'confidence')::numeric,r->>'extractor_version');
 END LOOP;
 UPDATE knowledge.sourcerevision source SET processingstatus='READY',processedat=now()
 WHERE source.sourcerevisionid=v_source;
 IF v_doc IS NOT NULL THEN
   UPDATE knowledge.documentversion SET ocrstatus=CASE WHEN mimetype='application/pdf' THEN 'COMPLETED' ELSE 'NOT_NEEDED' END,
      ocrengineversion=p_ocrengineversion WHERE documentversionid=v_doc;
   UPDATE social.documentdetail SET documentstatus='READY' WHERE contentid=v_content;
 END IF;
 UPDATE ops.indexoutbox SET eventstatus='DONE',processedat=now(),claimtoken=NULL,leaseuntil=NULL,lasterror=NULL
 WHERE eventid=p_eventid AND claimtoken=p_claimtoken AND eventstatus='CLAIMED' AND leaseuntil>now();
 IF NOT FOUND THEN RAISE EXCEPTION 'Index claim expired during commit' USING ERRCODE='P0002'; END IF;
 sourcerevisionid:=v_source;chunkcount:=v_chunkcount;entitycount:=v_entitycount;
 RETURN NEXT;
END;
$$;
