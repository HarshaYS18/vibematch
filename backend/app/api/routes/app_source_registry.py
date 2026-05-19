from fastapi import APIRouter, Depends

from app.api.routes.users import get_current_user
from app.models.user import User
from app.schemas.app_source_registry import AppSourceRegistryResponse
from app.services import app_source_registry_service

router = APIRouter(prefix="/app", tags=["App Source Registry"])


@router.get("/source-of-truth/master", response_model=AppSourceRegistryResponse)
def get_master_source_registry(current_user: User = Depends(get_current_user)):
    return app_source_registry_service.get_app_source_registry()
