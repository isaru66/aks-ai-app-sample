from fastapi import APIRouter
from app.api.v1.endpoints import chat, health, rag, agents

# Create API v1 router
api_router = APIRouter()

# Include endpoint routers
api_router.include_router(
    health.router,
    prefix="/health",
    tags=["Health"]
)

api_router.include_router(
    chat.router,
    prefix="/chat",
    tags=["Chat"]
)

api_router.include_router(
    rag.router,
    prefix="/rag",
    tags=["RAG"]
)

api_router.include_router(
    agents.router,
    prefix="/agents",
    tags=["Agents"]
)
