from app.core.cache_policy import SPECS, cache_key


def test_cache_keys_hide_raw_identifiers():
    key = cache_key(SPECS["public_profile"], "USER-SECRET-123")
    assert "USER-SECRET-123" not in key
    assert key.startswith("funkey:cache:v1:public_profile:")


def test_only_approved_reconstructable_namespaces_exist():
    assert "wallet" not in SPECS
    assert "session" not in SPECS
    assert "authorization" not in SPECS
