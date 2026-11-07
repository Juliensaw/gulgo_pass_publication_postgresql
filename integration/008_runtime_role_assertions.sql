-- Validate runtime role grants without persisting fixtures.
BEGIN;
DO $$
DECLARE r record; m record;
BEGIN
 SELECT rolcanlogin, rolsuper, rolbypassrls, rolinherit INTO r
 FROM pg_roles WHERE rolname='gulgo_runtime';
 IF NOT FOUND OR NOT r.rolcanlogin OR r.rolsuper OR r.rolbypassrls OR r.rolinherit
 THEN RAISE EXCEPTION 'Runtime role is unsafe'; END IF;
 SELECT am.inherit_option, am.set_option INTO m
 FROM pg_auth_members am JOIN pg_roles member ON member.oid=am.member
 JOIN pg_roles role ON role.oid=am.roleid
 WHERE member.rolname='gulgo_runtime' AND role.rolname='gulgo_api';
 IF NOT FOUND OR m.inherit_option OR NOT m.set_option
 THEN RAISE EXCEPTION 'Unsafe role membership'; END IF;
 IF EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  JOIN pg_roles r ON r.oid=c.relowner
  WHERE n.nspname='public' AND c.relkind IN ('r','p')
  AND r.rolname IN ('gulgo_runtime','gulgo_api')
 ) THEN RAISE EXCEPTION 'Runtime role owns protected tables'; END IF;
END $$;
ROLLBACK;
