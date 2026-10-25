-- Apply as the schema owner. This migration creates restricted NOLOGIN roles.
-- Enable LOGIN on these roles after deployment; set passwords outside SQL Editor.
CREATE OR REPLACE FUNCTION ops.has_pending_index_outbox()
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT EXISTS (SELECT 1 FROM ops.indexoutbox
   WHERE eventstatus='PENDING' OR (eventstatus='CLAIMED' AND leaseuntil<now()));
$$;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='coursework_api') THEN
   CREATE ROLE coursework_api NOLOGIN;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='coursework_worker') THEN
   CREATE ROLE coursework_worker NOLOGIN;
 END IF;
END $$;

-- Avoid leaking table reads or helper calls through PostgreSQL's default PUBLIC privileges.
REVOKE ALL ON SCHEMA auth,social,knowledge,assistant,ops FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA auth,social,knowledge,assistant,ops FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA auth,social,knowledge,assistant,ops FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA auth,social,knowledge,assistant,ops FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
-- PostgreSQL grants EXECUTE on newly created functions to PUBLIC by default.
-- Keep later migrations private until they grant a reviewed entry point.
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
GRANT USAGE ON SCHEMA auth,social,knowledge,assistant TO coursework_api;
GRANT USAGE ON SCHEMA ops TO coursework_worker;

-- Every entry point executes with the migration owner's rights; fixed search_path
-- prevents a caller from substituting objects through its own schema or pg_temp.
DO $$ DECLARE fn record; BEGIN
 FOR fn IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('auth','social','knowledge','assistant','ops')
 LOOP
   EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp',fn.signature);
 END LOOP;
END $$;

DO $$ DECLARE fn record; BEGIN
 FOR fn IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('auth','social','knowledge','assistant') AND p.proname LIKE 'usp_%'
 LOOP
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO coursework_api',fn.signature);
 END LOOP;
 FOR fn IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='ops' AND p.proname IN
     ('has_pending_index_outbox','claim_index_outbox','get_claimed_index_source',
      'renew_index_lease','complete_index_outbox','requeue_expired_index_outbox',
      'commit_index_result','commit_index_deletion')
 LOOP
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO coursework_worker',fn.signature);
 END LOOP;
END $$;
