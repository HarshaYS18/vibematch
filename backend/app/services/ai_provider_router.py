import os
from dataclasses import dataclass


@dataclass(frozen=True)
class AiProviderConfig:
    provider: str
    model: str | None
    configured: bool


def configured_provider() -> AiProviderConfig:
    requested = (os.getenv("FUNKEY_AI_PROVIDER") or "local_rules").strip().lower()
    providers = {
        "gemini": ("GEMINI_API_KEY", os.getenv("GEMINI_MODEL") or "gemini-1.5-flash"),
        "groq": ("GROQ_API_KEY", os.getenv("GROQ_MODEL") or "llama-3.1-8b-instant"),
        "openrouter": ("OPENROUTER_API_KEY", os.getenv("OPENROUTER_MODEL") or "openrouter/auto"),
    }
    if requested in providers:
        env_key, model = providers[requested]
        return AiProviderConfig(provider=requested, model=model, configured=bool(os.getenv(env_key)))
    return AiProviderConfig(provider="local_rules", model=None, configured=True)


def safe_provider_name() -> str:
    config = configured_provider()
    if config.provider == "local_rules" or config.configured:
        return config.provider
    return "local_rules"
