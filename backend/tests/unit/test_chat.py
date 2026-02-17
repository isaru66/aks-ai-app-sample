import pytest
from app.models.schemas import ThinkingStep, ChatMessage, MessageRole


def test_thinking_step_model():
    """Test ThinkingStep model."""
    step = ThinkingStep(
        step_number=1,
        reasoning="First, analyze the problem...",
        confidence=0.95
    )
    
    assert step.step_number == 1
    assert step.reasoning == "First, analyze the problem..."
    assert step.confidence == 0.95
    assert 0.0 <= step.confidence <= 1.0


def test_chat_message_with_thinking():
    """Test ChatMessage with thinking steps."""
    thinking_steps = [
        ThinkingStep(
            step_number=1,
            reasoning="Step 1 reasoning",
            confidence=0.9
        ),
        ThinkingStep(
            step_number=2,
            reasoning="Step 2 reasoning",
            confidence=0.95
        )
    ]
    
    message = ChatMessage(
        role=MessageRole.ASSISTANT,
        content="This is the response",
        thinking_steps=thinking_steps
    )
    
    assert message.role == MessageRole.ASSISTANT
    assert len(message.thinking_steps) == 2
    assert message.thinking_steps[0].step_number == 1


def test_chat_message_without_thinking():
    """Test ChatMessage without thinking steps."""
    message = ChatMessage(
        role=MessageRole.USER,
        content="User question"
    )
    
    assert message.role == MessageRole.USER
    assert message.thinking_steps is None
