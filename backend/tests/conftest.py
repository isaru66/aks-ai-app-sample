import pytest
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture
def client():
    """Test client fixture."""
    return TestClient(app)


@pytest.fixture
def sample_messages():
    """Sample chat messages."""
    return [
        {"role": "user", "content": "What is quantum computing?"}
    ]


@pytest.fixture
def sample_chat_request():
    """Sample chat request."""
    return {
        "messages": [
            {"role": "user", "content": "Explain quantum computing"}
        ],
        "show_thinking": True,
        "stream": True
    }
