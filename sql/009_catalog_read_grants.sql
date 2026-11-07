-- V1.1 controlled read access to immutable methodology reference tables.
-- The content is reference metadata, not tenant data. API checks dossier
-- visibility before displaying a methodology-specific catalogue.
BEGIN;
GRANT SELECT ON public.methodology_release,
    public.indicator_definition, public.indicator_variable,
    public.variable_definition TO gulgo_api;
COMMIT;
