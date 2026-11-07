"""Descriptive PASS pilot report. No scoring, eligibility or certification."""
from collections import defaultdict
from datetime import datetime, timezone
from html import escape
from io import BytesIO
import json

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, KeepTogether


def _safe(value, limit=900):
    if value is None:
        return "Non renseigné"
    if isinstance(value, (dict, list)):
        value = json.dumps(value, ensure_ascii=False, sort_keys=True)
    text = str(value).replace("\x00", "").strip()
    return escape(text[:limit] + ("…" if len(text) > limit else ""))


def generate_descriptive_report(dossier, catalogue, observation_history):
    """Return PDF bytes using only authenticated, already-scoped API data."""
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=21*mm,
                            rightMargin=21*mm, topMargin=22*mm, bottomMargin=22*mm,
                            title="GULGO PASS - Rapport descriptif de démonstration",
                            author="GULGO PASS")
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="PassTitle", parent=styles["Title"],
                              textColor=colors.HexColor("#173b5a"), fontSize=17,
                              leading=22, spaceAfter=12, alignment=TA_LEFT))
    styles.add(ParagraphStyle(name="PassDimension", parent=styles["Heading2"],
                              textColor=colors.HexColor("#173b5a"), fontSize=11,
                              leading=15, spaceBefore=13, spaceAfter=5))
    styles.add(ParagraphStyle(name="PassSmall", parent=styles["BodyText"],
                              fontSize=8.4, leading=12, spaceAfter=4))
    styles.add(ParagraphStyle(name="PassNotice", parent=styles["BodyText"],
                              textColor=colors.HexColor("#7a3d16"),
                              fontSize=9, leading=13, spaceAfter=12))

    story = [
        Paragraph("GULGO PASS - Rapport descriptif", styles["PassTitle"]),
        Paragraph("DÉMONSTRATEUR - DONNÉES FICTIVES UNIQUEMENT. "
                  "Document non certifié, sans score, sans avis de solvabilité "
                  "et sans décision d'admissibilité.", styles["PassNotice"]),
        Paragraph("Dossier : " + _safe(dossier["id"], 100), styles["PassSmall"]),
        Paragraph("Activité économique (identifiant) : " + _safe(dossier["subject_id"], 100), styles["PassSmall"]),
        Paragraph("Statut : " + _safe(dossier["status"], 100)
                  + " | Révision : " + _safe(dossier["revision"], 100), styles["PassSmall"]),
        Paragraph("Méthodologie : " + _safe(catalogue["methodology_id"], 120), styles["PassSmall"]),
        Paragraph("Édité le (UTC) : " + datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M"), styles["PassSmall"]),
        Spacer(1, 8),
    ]
    variable_dimensions = defaultdict(set)
    for dimension in catalogue["dimensions"]:
        for indicator in dimension["indicators"]:
            for variable in indicator["variables"]:
                variable_dimensions[variable["code"]].add(dimension["code"])

    buckets = defaultdict(list)
    observations = observation_history["observations"]
    for observation in observations:
        matching = variable_dimensions.get(observation["variable_code"], set())
        # Do not assign an ambiguous variable arbitrarily to one dimension.
        bucket = next(iter(matching)) if len(matching) == 1 else "UNMAPPED"
        buckets[bucket].append(observation)

    def add_observation(obs):
        rows = [
            Paragraph("Variable : " + _safe(obs["variable_code"], 130)
                      + " | État : " + _safe(obs["data_status"], 100), styles["PassSmall"]),
            Paragraph("Valeur déclarée : " + _safe(obs["value"]), styles["PassSmall"]),
            Paragraph("Source : " + _safe(obs["source_type"], 160)
                      + " | Début : " + _safe(obs["period_start"], 60)
                      + " | Fin : " + _safe(obs["period_end"], 60), styles["PassSmall"]),
            Paragraph("Observation : " + _safe(obs["id"], 100)
                      + " | Enregistrée : " + _safe(obs["recorded_at"], 100), styles["PassSmall"]),
        ]
        if obs["supersedes_id"]:
            rows.append(Paragraph("Corrige l'observation : "
                                  + _safe(obs["supersedes_id"], 100), styles["PassSmall"]))
        rows.append(Spacer(1, 7))
        story.append(KeepTogether(rows))

    for dimension in catalogue["dimensions"]:
        code = dimension["code"]
        story.append(Paragraph(_safe(code, 8) + " - " + _safe(dimension["label"], 160),
                               styles["PassDimension"]))
        records = buckets.get(code, [])
        if not records:
            story.append(Paragraph("Aucune observation rattachée dans l'extrait.",
                                   styles["PassSmall"]))
        else:
            for observation in records:
                add_observation(observation)

    if buckets["UNMAPPED"]:
        story.append(Paragraph("Observations non rattachées sans ambiguïté à une dimension",
                               styles["PassDimension"]))
        for observation in buckets["UNMAPPED"]:
            add_observation(observation)

    if not observations:
        story.append(Paragraph("Aucune observation enregistrée dans cet extrait.",
                               styles["PassSmall"]))
    story.extend([
        Spacer(1, 12),
        Paragraph("Limites et interprétation", styles["PassDimension"]),
        Paragraph("Ce rapport reproduit uniquement les observations accessibles et "
                  "les correspondances explicites du catalogue métier. Il ne vérifie "
                  "pas l'authenticité des déclarations ou des justificatifs.",
                  styles["PassSmall"]),
        Paragraph("L'historique source est limité à "
                  + _safe(observation_history.get("limit", 100), 30)
                  + " observations ; si ce plafond est atteint, l'extrait peut être incomplet.",
                  styles["PassSmall"]),
        Paragraph("Les valeurs successives sont présentées à titre d'historique, "
                  "sans sélection automatique d'une valeur faisant autorité. "
                  "Aucune conclusion de crédit ou de financement ne peut en être tirée.",
                  styles["PassSmall"]),
    ])
    doc.build(story)
    return buffer.getvalue()
