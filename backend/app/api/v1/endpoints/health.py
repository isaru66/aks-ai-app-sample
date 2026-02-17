from fastapi import APIRouter
from app.models.schemas import HealthResponse
from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()


@router.get("/", response_model=HealthResponse)
async def health_check():
    """
    Basic health check endpoint.
    
    Returns:
        Health status
    """
    return HealthResponse(
        status="healthy",
        version=settings.api_version,
        environment=settings.environment
    )


@router.get("/ready", response_model=HealthResponse)
async def readiness_check():
    """
    Kubernetes readiness probe.
    
    Checks if the service is ready to accept requests.
    
    Returns:
        Readiness status with service checks
    """
    services_status = {}
    
    # Check Azure OpenAI
    try:
        from app.services.openai_service import openai_service
        services_status["openai"] = "healthy" if openai_service.client else "unavailable"
    except Exception as e:
        services_status["openai"] = f"error: {str(e)}"
    
    # Check database
    try:
        from app.repositories.factory import get_repository
        repository = get_repository()
        services_status["database"] = f"healthy ({settings.database_type})"
    except Exception as e:
        services_status["database"] = f"error: {str(e)}"
    
    # Check Azure AI Search
    try:
        from app.services.search_service import search_service
        services_status["search"] = "healthy" if search_service.client else "unavailable"
    except Exception as e:
        services_status["search"] = f"error: {str(e)}"
    
    # Determine overall status
    overall_status = "healthy" if all(
        status == "healthy" for status in services_status.values()
    ) else "degraded"
    
    return HealthResponse(
        status=overall_status,
        version=settings.api_version,
        environment=settings.environment,
        services=services_status
    )


@router.get("/live", response_model=HealthResponse)
async def liveness_check():
    """
    Kubernetes liveness probe.
    
    Checks if the service is alive.
    
    Returns:
        Liveness status
    """
    return HealthResponse(
        status="alive",
        version=settings.api_version,
        environment=settings.environment
    )
