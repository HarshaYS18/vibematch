from app.services.feature_flag_service import EvaluationContext, evaluate_boolean


def test_percentage_rollout_is_stable():
    context = EvaluationContext(
        targeting_key="user-123",
        platform="android",
        app_version="1.0.0",
    )
    first = evaluate_boolean("recommendation_personalization", context)
    second = evaluate_boolean("recommendation_personalization", context)
    assert first.value == second.value
    assert first.metadata.get("bucket") == second.metadata.get("bucket")


def test_platform_mismatch_uses_default():
    result = evaluate_boolean(
        "recommendation_personalization",
        EvaluationContext(targeting_key="user", platform="desktop", app_version="1.0.0"),
    )
    assert result.value is False
