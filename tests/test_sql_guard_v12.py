"""Unit checks for the API SQL guard; not a replacement for PostgreSQL RLS tests."""
import pytest
from fastapi import HTTPException
from src.api.main import validate_api_sql


@pytest.mark.parametrize("sql", [
    "SELECT id FROM pass_dossier",
    "  SELECT id FROM pass_dossier WHERE id=%s ",
    "SELECT i.code FROM indicator_definition AS i LEFT JOIN indicator_variable AS v ON v.indicator_code=i.code",
    "SELECT gulgo_create_dossier(%s,%s)::text",
])
def test_allowed_single_select(sql):
    validate_api_sql(sql)


@pytest.mark.parametrize("sql", [
    "SET ROLE gulgo_owner",
    "SELECT 1; SELECT 2",
    "SELECT set_config('app.current_user_id', 'fake', true)",
    "SELECT current_setting('app.current_user_id')",
    "SELECT id FROM pass_dossier -- bypass",
    "SELECT id FROM pass_dossier /* bypass */",
    "DELETE FROM pass_dossier",
    "SELECT pg_sleep(1)",
])
def test_reject_dangerous_sql(sql):
    with pytest.raises(HTTPException) as exc:
        validate_api_sql(sql)
    assert exc.value.status_code == 503
