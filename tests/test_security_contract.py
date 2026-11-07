import unittest
from pathlib import Path

SQL = (Path(__file__).resolve().parents[1] / "sql" / "002_integrity_security.sql").read_text()

class SecurityContractTests(unittest.TestCase):
    def test_transactional_migration(self):
        self.assertTrue(SQL.strip().startswith("-- GULGO PASS"))
        self.assertIn("BEGIN;", SQL)
        self.assertTrue(SQL.strip().endswith("COMMIT;"))

    def test_dossier_bound_evidence(self):
        self.assertIn("fk_supersession_same_dossier_method", SQL)
        self.assertIn("fk_observation_dossier_method", SQL)

    def test_rls_and_fail_closed(self):
        for table in ("economic_subject", "pass_dossier", "variable_observation", "evidence", "evidence_link", "commercial_relationship", "commitment", "incident", "organization_practice", "economic_vulnerability", "control_finding", "assessment_run", "assessment_result"):
            self.assertIn(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY", SQL)
        self.assertNotIn("FOR INSERT WITH CHECK", SQL)

    def test_immutability(self):
        for table in ("variable_observation", "evidence", "assessment_result", "audit_event", "methodology_release"):
            self.assertIn(f"BEFORE UPDATE OR DELETE ON {table}", SQL)

    def test_scoring_still_disabled(self):
        initial = (Path(__file__).resolve().parents[1] / "sql" / "001_init.sql").read_text()
        self.assertIn("CHECK (scoring_enabled = FALSE)", initial)

if __name__ == "__main__": unittest.main()
