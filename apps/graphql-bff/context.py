"""Per-request GraphQL context and request-scoped DataLoaders."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any

from dataloader import DataLoader
from upstream import RequestMetadata, UpstreamClient


@dataclass
class GraphQLRequestContext:
    upstream: UpstreamClient
    metadata: RequestMetadata
    profile_loader: DataLoader
    user_vibes_loader: DataLoader

    @classmethod
    def build(
        cls,
        upstream: UpstreamClient,
        metadata: RequestMetadata,
    ) -> "GraphQLRequestContext":
        async def batch_profiles(keys: list[object]) -> dict[object, Any]:
            async def one(key: object) -> tuple[object, Any]:
                value = await upstream.get_json(
                    "profile",
                    f"/profile-display/users/{key}",
                )
                return key, value

            pairs = await asyncio.gather(*(one(key) for key in keys))
            return dict(pairs)

        async def batch_user_vibes(keys: list[object]) -> dict[object, Any]:
            async def one(key: object) -> tuple[object, Any]:
                public_user_id, limit = key  # type: ignore[misc]
                value = await upstream.get_json(
                    "vibes",
                    f"/vibes/user/{public_user_id}",
                    params={"limit": int(limit)},
                )
                return key, value

            pairs = await asyncio.gather(*(one(key) for key in keys))
            return dict(pairs)

        return cls(
            upstream=upstream,
            metadata=metadata,
            profile_loader=DataLoader(batch_profiles),
            user_vibes_loader=DataLoader(batch_user_vibes),
        )
