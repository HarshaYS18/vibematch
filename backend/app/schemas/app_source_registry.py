from typing import Any

from pydantic import BaseModel, Field


class SourceEndpoint(BaseModel):
    path: str
    purpose: str
    owner: str = "backend"
    realtime_safe: bool = True


class TabSourceRegistryItem(BaseModel):
    tab_key: str
    label: str
    master_read: str
    canonical_owner: str = "backend"
    child_reads: list[SourceEndpoint] = Field(default_factory=list)
    child_writes: list[SourceEndpoint] = Field(default_factory=list)
    config_sources: list[SourceEndpoint] = Field(default_factory=list)
    control_center_modules: list[str] = Field(default_factory=list)
    realtime_channels: list[str] = Field(default_factory=list)
    protected_flows: list[str] = Field(default_factory=list)
    duplicate_sources_to_retire: list[str] = Field(default_factory=list)
    migration_status: str = "foundation"


class AppSourceRegistryResponse(BaseModel):
    version: int
    master_api: SourceEndpoint
    rules: dict[str, Any]
    tabs: list[TabSourceRegistryItem]
    deferred_work: list[str] = Field(default_factory=list)
