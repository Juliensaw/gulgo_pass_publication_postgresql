"""Regression checks for fail-closed database session security."""
from pathlib import Path

API = Path("src/api/main.py").read_text(encoding="utf-8")


def test_database_session_checks_effective_role():
    assert 'role_row[0] != "gulgo_api"' in API


def test_database_session_rejects_privileged_login():
    assert 'role_row[1] != "gulgo_runtime"' in API
    assert 'role_row[3] != "off"' in API
    assert "role_row[4] or role_row[5] or role_row[6]" in API


def test_database_session_requires_rls_enabled():
    assert 'role_row[2] != "on"' in API


def test_identity_set_only_after_role_guard():
    assert API.index("Unsafe database role configuration") < API.index("set_config('app.current_user_id'")


def test_runtime_login_must_be_non_privileged_and_unable_to_create_objects():
    assert "login.rolcanlogin, login.rolsuper" in API
    assert "login.rolbypassrls, login.rolcreatedb" in API
    assert "login.rolcreaterole" in API
    assert "has_schema_privilege(session_user, 'public', 'CREATE')" in API
    assert "has_database_privilege(session_user, current_database(), 'CREATE')" in API
    assert "not role_row[7] or any(role_row[8:14])" in API
