from app.services.risk_policy_service import RiskSignal, evaluate


def test_empty_risk_allows():
    decision = evaluate([])
    assert decision.score == 0
    assert decision.action == "allow"


def test_high_risk_requires_review_not_silent_irreversible_action():
    decision = evaluate([
        RiskSignal("payment_velocity", 92, "PAYMENT_VELOCITY"),
        RiskSignal("device_abuse", 40, "DEVICE_REUSE"),
    ])
    assert decision.score >= 90
    assert decision.action == "temporary_hold_and_manual_review"
    assert "PAYMENT_VELOCITY" in decision.reasons
