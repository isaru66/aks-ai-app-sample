from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import time
import uuid
from app.core.config import settings
from app.core.logging import get_logger, setup_logging
from app.api.router import api_router

# Setup logging
setup_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    # Startup
    logger.info(f"Starting {settings.app_name} - Environment: {settings.environment}")
    logger.info(f"GPT Model: {settings.azure_openai_model}")
    logger.info(f"Streaming: {settings.enable_streaming}")
    logger.info(f"Thinking Process: {settings.enable_thinking_process}")
    
    # Initialize services (lazy loading handled in services)
    try:
        from app.services.openai_service import openai_service
        from app.repositories.factory import get_repository
        repository = get_repository()
        logger.info("✅ Services initialized successfully")
    except Exception as e:
        logger.error(f"❌ Error initializing services: {e}")
    
    yield
    
    # Shutdown
    logger.info(f"Shutting down {settings.app_name}")


# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    description="Azure AI Chat Application with GPT-5.2 Streaming and Thinking Visualization",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)


# Middleware: CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)


# NOTE: GZipMiddleware removed - it buffers entire responses before sending,
# which completely breaks SSE streaming. For non-streaming endpoints, consider
# applying compression at the reverse proxy level (nginx/ingress).


# Middleware: Request ID and timing
@app.middleware("http")
async def add_request_id_and_timing(request: Request, call_next):
    """Add request ID and measure request duration."""
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    start_time = time.time()
    
    response = await call_next(request)
    
    duration = time.time() - start_time
    
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time"] = str(duration)
    
    logger.info(
        f"Request: {request.method} {request.url.path} - "
        f"Status: {response.status_code} - "
        f"Duration: {duration:.3f}s - "
        f"Request-ID: {request_id}"
    )
    
    return response


# Exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": str(exc),
            "request_id": getattr(request.state, "request_id", None)
        }
    )


# Include API router
app.include_router(
    api_router,
    prefix="/api/v1"
)


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "app": settings.app_name,
        "version": "1.0.0",
        "environment": settings.environment,
        "docs": "/docs",
        "health": "/api/v1/health"
    }


# OpenAPI customization
app.openapi_tags = [
    {
        "name": "Health",
        "description": "Health check endpoints for Kubernetes probes"
    },
    {
        "name": "Chat",
        "description": "GPT-5.2 chat endpoints with streaming and thinking visualization"
    },
    {
        "name": "RAG",
        "description": "Retrieval Augmented Generation endpoints"
    },
    {
        "name": "Agents",
        "description": "AI Agent orchestration endpoints"
    }
]


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "app.main:app",
        host=settings.backend_host,
        port=settings.backend_port,
        reload=settings.debug,
        log_level=settings.log_level.lower()
    )
