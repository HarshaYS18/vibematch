from pydantic import BaseModel, Field, HttpUrl


class MediaNodeHeartbeatRequest(BaseModel):
    node_id: str = Field(..., min_length=1, max_length=120)
    public_url: HttpUrl
    room_count: int = Field(default=0, ge=0)
    peer_count: int = Field(default=0, ge=0)
    max_rooms: int = Field(default=250, gt=0)
    max_peers: int = Field(default=5000, gt=0)
    room_ids: list[str] = Field(default_factory=list, max_length=1000)


class MediaNodeResponse(BaseModel):
    node_id: str
    public_url: str
    room_count: int
    peer_count: int
    max_rooms: int
    max_peers: int
    draining: bool
    updated_at: float


class MediaNodeDrainRequest(BaseModel):
    draining: bool = True


class RoomMediaAssignmentResponse(BaseModel):
    room_public_id: str
    node_id: str
    signaling_url: str
    assignment_ttl_seconds: int
