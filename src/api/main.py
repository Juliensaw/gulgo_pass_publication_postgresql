"""GULGO PASS pilot API: controlled dossier writes; scoring disabled."""
import os
import re
from pathlib import Path
from fastapi.responses import HTMLResponse, Response
from datetime import datetime, timezone
from uuid import UUID
import jwt
from fastapi import FastAPI, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from datetime import date
import json
import hmac
import hashlib

app = FastAPI(title="GULGO PASS API", version="0.5.0")

class Principal(BaseModel):
    user_id: UUID


def verify_token(authorization: str | None = Header(default=None)) -> Principal:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Bearer token required")
    secret = os.environ.get("GULGO_JWT_SECRET", "")
    if len(secret) < 32:
        raise HTTPException(503, "Token verification not configured")
    try:
        claims = jwt.decode(authorization[7:], secret, algorithms=["HS256"],
                            audience="gulgo-api", issuer="gulgo-auth",
                            options={"require": ["sub", "exp", "iat", "aud", "iss"]},
                            leeway=0)
        return Principal(user_id=UUID(claims["sub"]))
    except (jwt.PyJWTError, ValueError, KeyError):
        raise HTTPException(401, "Invalid or expired token")


def validate_api_sql(sql: str) -> None:
    """Defense in depth: accept only one developer-authored SELECT statement.

    This is not a SQL parser or a fix for direct SQL access/GUC spoofing.
    """
    statement = sql.strip()
    if (not re.match(r"(?is)^SELECT\s+", statement)
            or re.search(r";|--|/\*|\*/", statement)
            or re.search(r"(?i)\b(?:set_config|current_setting|set|reset|copy|"
                         r"pg_sleep|dblink|lo_import|lo_export)\s*\(", statement)):
        raise HTTPException(503, "Unsafe application SQL")


def query_as_actor(actor: UUID, sql: str, args: tuple=()):
    """Transaction-local identity; database credentials never supplied by caller."""
    validate_api_sql(sql)
    try:
        import psycopg
    except ImportError as exc:
        raise HTTPException(503, "PostgreSQL driver unavailable") from exc
    dsn = os.environ.get("GULGO_DATABASE_URL")
    if not dsn:
        raise HTTPException(503, "Database not configured")
    try:
        with psycopg.connect(dsn, autocommit=False) as conn:
            with conn.transaction():
                with conn.cursor() as cur:
                    # Fail closed: API queries must run as the non-owner, non-BYPASSRLS role.
                    # Also reject an unexpectedly privileged runtime login, including
                    # schema/database CREATE grants that can enable escalation paths.
                    # Checking both session_user and current_user rejects privileged
                    # owner/superuser connections even if they SET ROLE gulgo_api.
                    # Runtime login must be a separate unprivileged role granted
                    # SET permission on gulgo_api. SET LOCAL applies only to
                    # this transaction and is checked against role membership.
                    cur.execute("SET LOCAL ROLE gulgo_api")
                    cur.execute("""
                        SELECT current_user, session_user,
                               current_setting('row_security'),
                               current_setting('is_superuser'),
                               r.rolbypassrls, r.rolsuper,
                               EXISTS (
                                 SELECT 1 FROM pg_class c
                                 JOIN pg_namespace n ON n.oid = c.relnamespace
                                 WHERE n.nspname = 'public'
                                   AND c.relname IN ('economic_subject', 'pass_dossier')
                                   AND c.relowner = (SELECT oid FROM pg_roles WHERE rolname = session_user)
                               ) AS owns_protected_table,
                               login.rolcanlogin, login.rolsuper,
                               login.rolbypassrls, login.rolcreatedb,
                               login.rolcreaterole,
                               has_schema_privilege(session_user, 'public', 'CREATE'),
                               has_database_privilege(session_user, current_database(), 'CREATE')
                        FROM pg_roles r
                        JOIN pg_roles login ON login.rolname = session_user
                        WHERE r.rolname = current_user
                    """)
                    role_row = cur.fetchone()
                    if (not role_row or role_row[0] != "gulgo_api"
                            or role_row[1] != "gulgo_runtime"
                            or role_row[2] != "on"
                            or role_row[3] != "off"
                            or role_row[4] or role_row[5] or role_row[6]
                            or not role_row[7] or any(role_row[8:14])):
                        raise HTTPException(503, "Unsafe database role configuration")
                    identity_secret = os.environ.get("GULGO_ACTOR_HMAC_SECRET", "")
                    if len(identity_secret) < 64 or len(identity_secret) % 2:
                        raise HTTPException(503, "Actor identity signing not configured")
                    # Must match the bytes provisioned in gulgo_identity_secret.
                    actor_mac = hmac.new(
                        bytes.fromhex(identity_secret),
                        ("gulgo-actor-v12:" + str(actor)).encode("utf-8"),
                        hashlib.sha256,
                    ).hexdigest()
                    cur.execute("SELECT set_config('app.current_user_id', %s, true)", (str(actor),))
                    cur.execute("SELECT set_config('app.actor_mac', %s, true)", (actor_mac,))
                    cur.execute(sql, args)
                    return cur.fetchall()
    except psycopg.Error as exc:
        # Do not expose SQL or connection information to callers.
        raise HTTPException(503, "Database operation failed") from exc

@app.get("/", response_class=HTMLResponse, include_in_schema=False)
def institutional_home():
    """Institutional prototype; no sign-up or pre-evaluation collection."""
    page = Path(__file__).with_name("home.html")
    return HTMLResponse(page.read_text(encoding="utf-8"), headers={
        "Cache-Control": "no-store",
        "Content-Security-Policy": (
            "default-src 'none'; style-src 'unsafe-inline'; "
            "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
        ),
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
    })


@app.get("/demo/pre-evaluation", response_class=HTMLResponse, include_in_schema=False)
def pre_evaluation_demo():
    """Anonymous orientation checklist: no scoring, eligibility decision or persistence."""
    page = Path(__file__).with_name("pre_evaluation_demo.html")
    return HTMLResponse(page.read_text(encoding="utf-8"), headers={
        "Cache-Control": "no-store",
        "Content-Security-Policy": (
            "default-src 'none'; script-src 'unsafe-inline'; "
            "style-src 'unsafe-inline'; form-action 'none'; "
            "base-uri 'none'; frame-ancestors 'none'"
        ),
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
    })


@app.get("/demo/pass", response_class=HTMLResponse, include_in_schema=False)
def pass_demo():
    """Non-production demonstration UI, served from the API's own origin."""
    page = Path(__file__).with_name("pass_demo.html")
    return HTMLResponse(page.read_text(encoding="utf-8"), headers={
        "Cache-Control": "no-store",
        "Content-Security-Policy": (
            "default-src 'none'; script-src 'unsafe-inline'; "
            "style-src 'unsafe-inline'; connect-src 'self'; "
            "img-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'"
        ),
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
    })


@app.get("/health")
def health():
    return {"status": "up", "version": "0.5.0", "database_checked": False}

@app.get("/api/v1/subjects")
def subjects(principal: Principal = Depends(verify_token)):
    rows = query_as_actor(principal.user_id,
        "SELECT id::text, kind, display_name FROM economic_subject ORDER BY display_name LIMIT 100")
    return [{"id": r[0], "kind": r[1], "display_name": r[2]} for r in rows]

@app.get("/api/v1/pass/dossiers")
def dossiers(principal: Principal = Depends(verify_token)):
    rows = query_as_actor(principal.user_id,
        "SELECT id::text, subject_id::text, status, revision FROM pass_dossier ORDER BY id LIMIT 100")
    return [{"id":r[0], "subject_id":r[1], "status":r[2], "revision":r[3]} for r in rows]

@app.get("/api/v1/pass/dossiers/{dossier_id}")
def dossier(dossier_id: UUID, principal: Principal = Depends(verify_token)):
    rows = query_as_actor(principal.user_id,
        "SELECT id::text, subject_id::text, status, revision FROM pass_dossier WHERE id=%s", (dossier_id,))
    if not rows:
        raise HTTPException(404, "Dossier not found")
    r=rows[0]
    return {"id":r[0], "subject_id":r[1], "status":r[2], "revision":r[3]}



@app.get("/api/v1/pass/dossiers/{dossier_id}/observations")
def dossier_observations(dossier_id: UUID, principal: Principal = Depends(verify_token)):
    """Return immutable observation history; no scoring or eligibility judgment."""
    rows = query_as_actor(principal.user_id, """
        SELECT o.id::text, o.variable_code, o.data_status, o.value_json,
               o.period_start, o.period_end, o.source_type,
               o.recorded_at, o.supersedes_id::text
        FROM variable_observation AS o
        WHERE o.dossier_id = %s
          AND EXISTS (SELECT 1 FROM pass_dossier AS d WHERE d.id = o.dossier_id)
        ORDER BY o.recorded_at DESC, o.id DESC
        LIMIT 100
    """, (dossier_id,))
    if not rows:
        # RLS intentionally makes an inaccessible dossier indistinguishable
        # from a missing dossier. An existing empty dossier is still readable.
        visible = query_as_actor(principal.user_id,
            "SELECT 1 FROM pass_dossier WHERE id=%s", (dossier_id,))
        if not visible:
            raise HTTPException(404, "Dossier not found")
    return {
        "dossier_id": str(dossier_id),
        "observations": [
            {"id": r[0], "variable_code": r[1], "data_status": r[2],
             "value": r[3], "period_start": r[4], "period_end": r[5],
             "source_type": r[6], "recorded_at": r[7], "supersedes_id": r[8]}
            for r in rows
        ],
        "limit": 100,
        "scoring_enabled": False,
    }


PASS_DIMENSIONS = {
    "D1": "Identité & existence",
    "D2": "Traçabilité & qualité des données",
    "D3": "Activité & régularité économique",
    "D4": "Discipline & engagements",
    "D5": "Performance & résilience",
    "D6": "Formalisation & gouvernance",
}


@app.get("/api/v1/pass/dossiers/{dossier_id}/catalog")
def dossier_catalog(dossier_id: UUID, principal: Principal = Depends(verify_token)):
    """Read variable/indicator catalogue for a visible dossier, never infer a score.

    Catalogue rows are methodology metadata. The dossier visibility check
    remains mandatory, including when no indicators have been registered.
    """
    dossier_rows = query_as_actor(
        principal.user_id,
        "SELECT methodology_id FROM pass_dossier WHERE id = %s",
        (dossier_id,),
    )
    if not dossier_rows:
        raise HTTPException(404, "Dossier not found")
    methodology_id = dossier_rows[0][0]
    rows = query_as_actor(principal.user_id, """
        SELECT i.dimension_code, i.code, i.label,
               v.code, v.label, v.value_type, v.critical
        FROM indicator_definition AS i
        LEFT JOIN indicator_variable AS iv
          ON iv.methodology_id = i.methodology_id
         AND iv.indicator_code = i.code
        LEFT JOIN variable_definition AS v
          ON v.methodology_id = iv.methodology_id
         AND v.code = iv.variable_code
        WHERE i.methodology_id = %s
        ORDER BY i.dimension_code, i.code, v.code
    """, (methodology_id,))
    dimensions = [
        {"code": code, "label": label, "indicators": []}
        for code, label in PASS_DIMENSIONS.items()
    ]
    by_dimension = {d["code"]: d for d in dimensions}
    indicators = {}
    for dimension_code, indicator_code, indicator_label, variable_code, variable_label, value_type, critical in rows:
        if dimension_code not in by_dimension:
            raise HTTPException(503, "Invalid methodology catalogue")
        key = (dimension_code, indicator_code)
        if key not in indicators:
            item = {"code": indicator_code, "label": indicator_label, "variables": []}
            by_dimension[dimension_code]["indicators"].append(item)
            indicators[key] = item
        if variable_code is not None:
            indicators[key]["variables"].append({
                "code": variable_code, "label": variable_label,
                "value_type": value_type, "critical": critical,
            })
    return {
        "dossier_id": str(dossier_id), "methodology_id": methodology_id,
        "dimensions": dimensions, "scoring_enabled": False,
        "catalogue_status": "configured" if rows else "not_configured",
    }


@app.get("/api/v1/pass/dossiers/{dossier_id}/report.pdf",
         response_class=Response)
def descriptive_report_pdf(dossier_id: UUID, principal: Principal = Depends(verify_token)):
    """Download a non-certified descriptive PDF; user scoping precedes generation."""
    from src.api.pass_report import generate_descriptive_report
    details = dossier(dossier_id, principal)
    catalogue = dossier_catalog(dossier_id, principal)
    history = dossier_observations(dossier_id, principal)
    pdf = generate_descriptive_report(details, catalogue, history)
    return Response(pdf, media_type="application/pdf", headers={
        "Content-Disposition": 'attachment; filename="gulgo-pass-descriptif.pdf"',
        "Cache-Control": "no-store, private",
        "X-Content-Type-Options": "nosniff",
    })


class CreateDossier(BaseModel):
    subject_id: UUID
    methodology_id: str = "GULGO_PASS_V1_PILOT"

class AppendObservation(BaseModel):
    variable_code: str = Field(min_length=1, max_length=100)
    value: object | None = None
    data_status: str
    period_start: date | None = None
    period_end: date | None = None
    source_type: str | None = Field(default=None, max_length=100)
    supersedes_id: UUID | None = None

@app.post("/api/v1/pass/dossiers", status_code=201)
def create_dossier(payload: CreateDossier, principal: Principal = Depends(verify_token)):
    rows = query_as_actor(principal.user_id,
        "SELECT gulgo_create_dossier(%s,%s)::text", (payload.subject_id, payload.methodology_id))
    return {"id": rows[0][0], "status": "draft"}

@app.post("/api/v1/pass/dossiers/{dossier_id}/observations", status_code=201)
def append_observation(dossier_id: UUID, payload: AppendObservation,
                       principal: Principal = Depends(verify_token)):
    rows = query_as_actor(principal.user_id,
        "SELECT gulgo_append_observation(%s,%s,%s::jsonb,%s,%s,%s,%s,%s)::text",
        (dossier_id, payload.variable_code,
         json.dumps(payload.value) if payload.value is not None else None,
         payload.data_status, payload.period_start, payload.period_end,
         payload.source_type, payload.supersedes_id))
    return {"id": rows[0][0], "dossier_id": str(dossier_id)}
