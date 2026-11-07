-- Catalogue metadata can be read but never changed by application role.
BEGIN;
SET LOCAL ROLE gulgo_api;
DO $$
DECLARE relation_name text;
BEGIN
 FOREACH relation_name IN ARRAY ARRAY[
   'methodology_release','indicator_definition',
   'indicator_variable','variable_definition'
 ] LOOP
   IF NOT has_table_privilege(current_user,format('public.%I',relation_name),'SELECT')
   THEN RAISE EXCEPTION 'Catalogue SELECT privilege missing: %',relation_name; END IF;
   IF has_table_privilege(current_user,format('public.%I',relation_name),'INSERT, UPDATE, DELETE')
   THEN RAISE EXCEPTION 'Catalogue write privilege leaked: %',relation_name; END IF;
 END LOOP;
END $$;
ROLLBACK;
