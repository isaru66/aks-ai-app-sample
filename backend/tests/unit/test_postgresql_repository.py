import pytest
import asyncio
from app.repositories.postgresql_repository import PostgreSQLRepository
from app.models.db_engine import db_engine
from app.core.config import settings


@pytest.fixture
def setup_db():
    """Setup test database."""
    if not settings.postgresql_url:
        pytest.skip("PostgreSQL not configured")
    
    db_engine.initialize()
    db_engine.create_tables()
    
    yield
    
    # Cleanup
    from app.models.db_models import Base
    Base.metadata.drop_all(bind=db_engine.engine)


@pytest.mark.asyncio
async def test_create_conversation(setup_db):
    """Test creating a conversation."""
    repo = PostgreSQLRepository()
    
    result = await repo.create_conversation(
        user_id="test-user-001",
        session_id="test-session-001",
        title="Test Conversation"
    )
    
    assert result["id"] == "test-session-001"
    assert result["userId"] == "test-user-001"
    assert result["title"] == "Test Conversation"
    assert result["messageCount"] == 0


@pytest.mark.asyncio
async def test_save_message_with_thinking(setup_db):
    """Test saving message with thinking steps."""
    repo = PostgreSQLRepository()
    
    # Create conversation first
    await repo.create_conversation(
        user_id="test-user-002",
        session_id="test-session-002"
    )
    
    # Save message with thinking steps
    thinking_steps = [
        {
            "step_number": 1,
            "reasoning": "First, I need to analyze the question",
            "confidence": 0.95,
            "timestamp": "2026-02-01T10:00:00"
        },
        {
            "step_number": 2,
            "reasoning": "Then, formulate a comprehensive response",
            "confidence": 0.92,
            "timestamp": "2026-02-01T10:00:01"
        }
    ]
    
    result = await repo.save_message(
        conversation_id="test-session-002",
        role="assistant",
        content="This is a test response with reasoning",
        thinking_steps=thinking_steps
    )
    
    assert result["conversationId"] == "test-session-002"
    assert result["role"] == "assistant"
    assert result["content"] == "This is a test response with reasoning"
    assert len(result["thinkingSteps"]) == 2
    assert result["thinkingSteps"][0]["reasoning"] == "First, I need to analyze the question"


@pytest.mark.asyncio
async def test_get_conversation_messages(setup_db):
    """Test retrieving messages for a conversation."""
    repo = PostgreSQLRepository()
    
    # Create conversation
    await repo.create_conversation(
        user_id="test-user-003",
        session_id="test-session-003"
    )
    
    # Add messages
    await repo.save_message(
        conversation_id="test-session-003",
        role="user",
        content="Hello"
    )
    
    await repo.save_message(
        conversation_id="test-session-003",
        role="assistant",
        content="Hi there!"
    )
    
    # Get messages
    messages = await repo.get_conversation_messages("test-session-003")
    
    assert len(messages) == 2
    assert messages[0]["role"] == "assistant"  # Most recent first
    assert messages[1]["role"] == "user"


@pytest.mark.asyncio
async def test_get_user_conversations(setup_db):
    """Test retrieving conversations for a user."""
    repo = PostgreSQLRepository()
    
    # Create multiple conversations
    await repo.create_conversation(
        user_id="test-user-004",
        session_id="test-session-004-1",
        title="First Conversation"
    )
    
    await repo.create_conversation(
        user_id="test-user-004",
        session_id="test-session-004-2",
        title="Second Conversation"
    )
    
    # Get conversations
    conversations = await repo.get_user_conversations("test-user-004")
    
    assert len(conversations) == 2
    assert conversations[0]["title"] in ["First Conversation", "Second Conversation"]


@pytest.mark.asyncio
async def test_update_conversation(setup_db):
    """Test updating conversation metadata."""
    repo = PostgreSQLRepository()
    
    # Create conversation
    await repo.create_conversation(
        user_id="test-user-005",
        session_id="test-session-005",
        title="Original Title"
    )
    
    # Update conversation
    result = await repo.update_conversation(
        session_id="test-session-005",
        updates={"title": "Updated Title"}
    )
    
    assert result["title"] == "Updated Title"
    assert result["sessionId"] == "test-session-005"
