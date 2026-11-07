import unittest
from src.calculations import relative_change, ratio, publication_gate
class CalculationsTest(unittest.TestCase):
    def test_growth(self): self.assertEqual(relative_change(10_000_000,12_000_000,True)['value'],'20.0')
    def test_zero_base(self): self.assertEqual(relative_change(0,5_000_000,True)['status'],'not_calculable')
    def test_missing(self): self.assertEqual(relative_change(None,100,True)['reason_code'],'MISSING_VALUE')
    def test_incomparable(self): self.assertEqual(relative_change(100,200,False)['reason_code'],'INCOMPARABLE_PERIODS')
    def test_ratio(self): self.assertEqual(ratio(7,10)['value'],'70.0')
    def test_zero_denominator(self): self.assertEqual(ratio(0,0)['status'],'not_calculable')
    def test_scoring_disabled(self): self.assertFalse(publication_gate(scoring_enabled=False,critical_missing=False,blocking_findings=False,approved=True)['score_allowed'])
if __name__=='__main__': unittest.main()
