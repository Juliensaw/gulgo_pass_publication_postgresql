"""Pilot descriptive calculations. No Score Pass scoring."""
from decimal import Decimal, InvalidOperation

def result(status, value=None, reason=None, unit='percent'):
    return {'status':status, 'value':str(value) if value is not None else None,
            'reason_code':reason, 'unit':unit, 'rule_version':'GULGO_PASS_V1_PILOT'}

def relative_change(previous, current, comparable):
    if previous is None or current is None:
        return result('not_calculable', reason='MISSING_VALUE')
    try:
        p, c = Decimal(str(previous)), Decimal(str(current))
        if not p.is_finite() or not c.is_finite() or p < 0 or c < 0:
            return result('not_calculable', reason='INVALID_VALUE')
    except (InvalidOperation, ValueError):
        return result('not_calculable', reason='INVALID_VALUE')
    if not comparable:
        return result('not_calculable', reason='INCOMPARABLE_PERIODS')
    if p == 0:
        return result('not_calculable', reason='ZERO_BASE')
    return result('calculated', (c-p)/p*100)

def ratio(numerator, denominator, *, zero_denominator='not_calculable'):
    if numerator is None or denominator is None:
        return result('not_calculable', reason='MISSING_VALUE')
    try:
        n, d = Decimal(str(numerator)), Decimal(str(denominator))
        if not n.is_finite() or not d.is_finite() or n < 0 or d < 0 or n > d:
            return result('not_calculable', reason='INVALID_COUNTS')
    except (InvalidOperation, ValueError):
        return result('not_calculable', reason='INVALID_VALUE')
    if d == 0:
        return result(zero_denominator, reason='ZERO_DENOMINATOR')
    return result('calculated', n/d*100)

def publication_gate(*, scoring_enabled, critical_missing, blocking_findings, approved):
    if not scoring_enabled:
        return {'score_allowed':False,'reason':'SCORING_DISABLED'}
    if critical_missing or blocking_findings or not approved:
        return {'score_allowed':False,'reason':'EVALUATION_INCOMPLETE'}
    return {'score_allowed':True,'reason':None}
