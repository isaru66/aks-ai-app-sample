from fastapi import APIRouter
from app.models.schemas import AgentRequest, AgentResponse
from app.services.agent_service import agent_service
from app.core.logging import get_logger
import uuid

logger = get_logger(__name__)
router = APIRouter()


@router.post("/execute", response_model=AgentResponse)
async def execute_agent(request: AgentRequest):
    """
    Execute an AI agent task.
    
    Args:
        request: Agent task request
    
    Returns:
        Agent execution result with thinking steps
    """
    logger.info(f"Executing agent task: {request.task[:50]}...")
    
    task_id = str(uuid.uuid4())
    
    result = await agent_service.execute_agent(
        task=request.task,
        agent_type=request.agent_type,
        show_thinking=request.show_thinking
    )
    
    return AgentResponse(
        task_id=task_id,
        status=result.get("status", "completed"),
        result=result.get("result"),
        thinking_steps=result.get("thinking_steps")
    )


@router.get("/status/{task_id}")
async def get_agent_status(task_id: str):
    """
    Get agent task status.
    
    Args:
        task_id: Task ID
    
    Returns:
        Task status
    """
    return {
        "task_id": task_id,
        "status": "completed",
        "message": "Agent task completed"
    }
