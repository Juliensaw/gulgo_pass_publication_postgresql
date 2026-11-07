"""Guard the HTTP-to-SQL boundary against dynamic query construction.

This is a structural regression check, not a substitute for SQL-injection
penetration testing or for the signed-identity architecture.
"""
import ast
from pathlib import Path

API = Path("src/api/main.py")


def test_all_http_database_queries_use_static_sql_templates():
    tree = ast.parse(API.read_text(encoding="utf-8"))
    calls = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "query_as_actor"
    ]
    assert len(calls) >= 8, "Expected all published routes to be covered"
    for call in calls:
        assert len(call.args) >= 2, "Actor and SQL template are required"
        assert isinstance(call.args[1], ast.Constant), (
            f"Dynamic SQL in API at line {call.lineno}; use a static query "
            "with separately bound parameters"
        )
        assert isinstance(call.args[1].value, str)
        assert "%" not in call.args[1].value.replace("%s", ""), (
            f"Unexpected percent-format SQL at line {call.lineno}"
        )


def test_no_public_endpoint_accepts_sql_text_as_input():
    tree = ast.parse(API.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and any(
            isinstance(dec, ast.Call)
            and isinstance(dec.func, ast.Attribute)
            and dec.func.attr in {"get", "post", "put", "patch", "delete"}
            for dec in node.decorator_list
        ):
            parameters = [arg.arg for arg in node.args.args]
            assert "sql" not in parameters
            assert "query" not in parameters
            assert "statement" not in parameters
