-- API functions are the only public interface. No worker or model access is needed.
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='coursework_api') THEN
   CREATE ROLE coursework_api NOLOGIN;
 END IF;
END $$;
REVOKE ALL ON SCHEMA auth,social,ops FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA auth,social,ops FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA auth,social,ops FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA auth,social,ops FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
GRANT USAGE ON SCHEMA auth,social TO coursework_api;
DO $$ DECLARE fn record; BEGIN
 FOR fn IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('auth','social','ops')
 LOOP
   EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp',fn.signature);
 END LOOP;
 FOR fn IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('auth','social') AND p.proname LIKE 'usp_%'
 LOOP
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO coursework_api',fn.signature);
 END LOOP;
END $$;
