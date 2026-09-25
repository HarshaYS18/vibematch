"""Disposable OpenSearch projection storage and query adapter."""

from __future__ import annotations

from typing import Any

import httpx

from contracts import SearchDocument


class OpenSearchStore:
    def __init__(self, client: httpx.AsyncClient, *, base_url: str, index_prefix: str) -> None:
        self._client = client
        self._base = base_url
        self._index = index_prefix

    @property
    def index_name(self) -> str:
        return self._index

    async def ensure_index(self) -> None:
        response = await self._client.head(f"{self._base}/{self._index}")
        if response.status_code == 200:
            return
        if response.status_code not in {404}:
            response.raise_for_status()
        mapping = {
            "settings": {"index": {"number_of_shards": 3, "number_of_replicas": 1}},
            "mappings": {
                "dynamic": "strict",
                "properties": {
                    "kind": {"type": "keyword"},
                    "public_id": {"type": "keyword"},
                    "title": {"type": "text", "fields": {"keyword": {"type": "keyword", "ignore_above": 256}}},
                    "subtitle": {"type": "text"},
                    "tags": {"type": "keyword"},
                    "keywords": {"type": "text"},
                    "image_url": {"type": "keyword", "index": False},
                    "language": {"type": "keyword"},
                    "popularity": {"type": "float"},
                    "updated_at": {"type": "date"},
                },
            },
        }
        created = await self._client.put(f"{self._base}/{self._index}", json=mapping)
        if created.status_code not in {200, 201}:
            created.raise_for_status()

    async def apply(self, document: SearchDocument) -> None:
        doc_id = f"{document.kind}:{document.public_id}"
        if document.deleted:
            response = await self._client.delete(
                f"{self._base}/{self._index}/_doc/{doc_id}",
                params={"refresh": "false"},
            )
            if response.status_code not in {200, 404}:
                response.raise_for_status()
            return
        body = document.model_dump(mode="json", exclude={"deleted"})
        response = await self._client.put(
            f"{self._base}/{self._index}/_doc/{doc_id}",
            json=body,
            params={"refresh": "false"},
        )
        response.raise_for_status()

    async def search(self, query: str, *, kinds: list[str], limit: int) -> list[dict[str, Any]]:
        must: list[dict[str, Any]] = [
            {
                "multi_match": {
                    "query": query,
                    "fields": ["title^4", "keywords^2", "subtitle", "tags"],
                    "type": "best_fields",
                    "fuzziness": "AUTO",
                }
            }
        ]
        filters: list[dict[str, Any]] = []
        if kinds:
            filters.append({"terms": {"kind": kinds}})
        body = {
            "size": limit,
            "track_total_hits": False,
            "query": {"bool": {"must": must, "filter": filters}},
            "sort": [{"_score": "desc"}, {"popularity": "desc"}, {"updated_at": "desc"}],
            "_source": [
                "kind", "public_id", "title", "subtitle", "tags", "image_url",
                "language", "popularity", "updated_at",
            ],
        }
        response = await self._client.post(
            f"{self._base}/{self._index}/_search",
            json=body,
        )
        response.raise_for_status()
        payload = response.json()
        hits = payload.get("hits", {}).get("hits", [])
        results: list[dict[str, Any]] = []
        for item in hits:
            source = dict(item.get("_source") or {})
            source["score"] = item.get("_score") or 0.0
            results.append(source)
        return results

    async def ready(self) -> bool:
        try:
            response = await self._client.get(f"{self._base}/_cluster/health", timeout=2)
            return response.status_code == 200
        except httpx.HTTPError:
            return False
