from pydantic import BaseModel, Field


class PushDeviceTokenUpsertRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=180)
    platform: str = Field(min_length=1, max_length=40)
    fcm_token: str = Field(min_length=20, max_length=700)
    app_package: str | None = Field(default=None, max_length=180)


class PushDeviceTokenResponse(BaseModel):
    ok: bool = True
    device_id: str
    platform: str
    is_active: bool
