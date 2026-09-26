"""Provision the canonical FunKey Kafka topic catalogue."""

import asyncio

from config import Settings
from topics import provision_topics


async def _run() -> None:
    settings = Settings.from_env()
    settings.validate()
    await provision_topics(settings)


if __name__ == "__main__":
    asyncio.run(_run())
