# Backend Application

FastAPI backend with **GPT-5.2 streaming**, **thinking visualization**, and LangGraph workflows.

## 🚀 Features

- ✅ **GPT-5.2 Streaming** - Real-time response streaming
- ✅ **Thinking Process Visualization** - Visible reasoning steps
- ✅ **Server-Sent Events (SSE)** - Efficient streaming protocol
- ✅ **LangGraph Workflows** - AI workflow orchestration
- ✅ **Azure AI Foundry Integration** - Unified AI platform
- ✅ **RAG (Retrieval Augmented Generation)** - Context-aware responses
- ✅ **Multi-Agent Support** - Agent orchestration
- ✅ **OpenTelemetry Tracing** - Distributed tracing

## 📁 Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI application
│   ├── core/                # Core configuration
│   │   ├── config.py        # Settings
│   │   ├── logging.py       # Logging setup
│   │   ├── security.py      # Auth & security
│   │   └── azure_auth.py    # Azure authentication
│   ├── api/                 # API endpoints
│   │   └── v1/
│   │       ├── endpoints/
│   │       │   ├── chat.py      # ⭐ STREAMING CHAT
│   │       │   ├── health.py    # Health checks
│   │       │   ├── rag.py       # RAG endpoints
│   │       │   └── agents.py    # Agent endpoints
│   │       └── deps.py      # Dependencies
│   ├── services/            # Azure services
│   │   ├── openai_service.py    # ⭐ GPT-5.2 WITH THINKING
│   │   ├── search_service.py    # Azure AI Search
│   │   ├── foundry_client.py    # AI Foundry
│   │   └── agent_service.py     # Agent service
│   ├── graphs/              # LangGraph workflows
│   │   ├── chat_graph.py    # Chat workflow
│   │   ├── rag_graph.py     # RAG workflow
│   │   └── agent_graph.py   # Multi-agent
│   ├── models/              # Data models
│   │   ├── schemas.py       # ⭐ Pydantic with ThinkingStep
│   │   └── database.py      # Cosmos DB client
│   └── utils/               # Utilities
│       ├── tracing.py       # OpenTelemetry
│       └── helpers.py       # Helper functions
├── tests/                   # Tests
│   ├── unit/
│   └── integration/
├── Dockerfile               # Multi-stage build
├── requirements.txt         # Dependencies
├── requirements-dev.txt     # Dev dependencies
├── pyproject.toml          # Python config
└── pytest.ini              # Pytest config
```

## 🔑 Key Components

### 1. GPT-5.2 Streaming with Thinking (`app/services/openai_service.py`)

```python
async def stream_chat_with_thinking(
    messages: List[Dict[str, str]],
    show_thinking: bool = True
) -> AsyncGenerator[StreamChunk, None]:
    """Stream GPT-5.2 with visible reasoning using Response API."""
    
    stream = await client.responses.create(
        model="gpt-5.2",
        input=messages,  # Response API uses 'input' instead of 'messages'
        stream=True,
        max_output_tokens=8000
    )
    
    # Process events (Response API uses event-based streaming)
    async for event in stream:
        event_type = event.get('type', '')
        
        # Yield thinking/reasoning
        if event_type == 'response.reasoning.delta':
            yield StreamChunk(
                type="thinking",
                content=event.get('delta', '')
            )
        
        # Yield content
        if event_type == 'response.output_text.delta':
            yield StreamChunk(
                type="content",
                content=event.get('delta', '')
            )
```

### 2. SSE Streaming Endpoint (`app/api/v1/endpoints/chat.py`)

```python
@router.post("/completions")
async def stream_chat_completion(request: ChatRequest):
    """Stream chat with SSE."""
    
    async def generate():
        async for chunk in chat_graph.stream_chat(messages):
            # Format as SSE
            yield f"data: {json.dumps(chunk.model_dump())}\n\n"
    
    return StreamingResponse(
        generate(),
        media_type="text/event-stream"
    )
```

### 3. Pydantic Models with ThinkingStep (`app/models/schemas.py`)

```python
class ThinkingStep(BaseModel):
    """GPT-5.2 thinking step."""
    step_number: int
    reasoning: str
    confidence: float  # 0.0 to 1.0
    timestamp: datetime

class ChatMessage(BaseModel):
    """Chat message with optional thinking."""
    role: MessageRole
    content: str
    thinking_steps: Optional[List[ThinkingStep]] = None
```

## 🚦 Quick Start

### 1. Install Dependencies

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

### 2. Configure Environment

```bash
# Copy environment template
cp ../.env.example ../.env

# Edit with your Azure credentials
nano ../.env
```

**Required variables**:
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_DEPLOYMENT_NAME=gpt-52-deployment`
- `AZURE_OPENAI_MODEL=gpt-5.2`
- `AZURE_COSMOSDB_ENDPOINT`
- `AZURE_COSMOSDB_KEY`
- `AZURE_SEARCH_ENDPOINT`
- `AZURE_SEARCH_API_KEY`

### 3. Run Development Server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or use the Makefile:

```bash
make backend-run
```

### 4. Access API Documentation

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

## 📡 API Endpoints

### Chat Endpoints

#### POST `/api/v1/chat/completions` ⭐
Stream chat with thinking visualization

**Request**:
```json
{
  "messages": [
    {"role": "user", "content": "Explain quantum computing"}
  ],
  "show_thinking": true,
  "stream": true
}
```

**Response** (SSE stream):
```
data: {"type": "thinking", "content": "First, I need to...", "metadata": {...}}

data: {"type": "content", "content": "Quantum computing...", "metadata": {...}}

data: {"type": "done", "content": "", "metadata": {...}}
```

#### POST `/api/v1/chat/completions/sync`
Non-streaming chat completion

#### GET `/api/v1/chat/history/{session_id}`
Get chat history

#### DELETE `/api/v1/chat/{session_id}`
Delete conversation

### RAG Endpoints

#### POST `/api/v1/rag/query`
Stream RAG query with document retrieval and thinking

#### POST `/api/v1/rag/index`
Index a document for search

### Agent Endpoints

#### POST `/api/v1/agents/execute`
Execute an AI agent task

#### GET `/api/v1/agents/status/{task_id}`
Get agent task status

### Health Endpoints

#### GET `/api/v1/health/`
Basic health check

#### GET `/api/v1/health/ready`
Readiness probe (checks Azure services)

#### GET `/api/v1/health/live`
Liveness probe

## 🧪 Testing

### Run All Tests

```bash
pytest tests/ -v
```

### Run Unit Tests Only

```bash
pytest tests/unit/ -v
```

### Run with Coverage

```bash
pytest tests/ -v --cov=app --cov-report=html
```

### View Coverage Report

```bash
open htmlcov/index.html
```

## 🐛 Debugging

### Enable Debug Mode

```bash
# In .env
LOG_LEVEL=DEBUG
```

### Test Streaming Endpoint

```bash
curl -X POST http://localhost:8000/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "show_thinking": true,
    "stream": true
  }'
```

### Check Logs

```bash
# Tail application logs
tail -f logs/app.log

# With Docker
docker-compose logs -f backend
```

## 🔐 Security

- ✅ **Managed Identity** for Azure services (production)
- ✅ **JWT Authentication** for API endpoints
- ✅ **CORS Configuration** for frontend access
- ✅ **Input Validation** with Pydantic
- ✅ **Rate Limiting** (configure in environment)

## 📊 Monitoring

### OpenTelemetry Tracing

Traces are sent to Application Insights:
- Request/response timings
- Thinking step tracking
- Error tracking
- Custom metrics

### Metrics

- Request count
- Response time
- Token usage
- Thinking steps per response
- Error rate

## 🔧 Configuration

### Environment Variables

See `.env.example` for all available settings.

**Key settings**:
- `ENABLE_STREAMING=true` - Enable streaming
- `ENABLE_THINKING_PROCESS=true` - Show thinking
- `GPT_THINKING_EFFORT=high` - Thinking detail level
- `GPT_MAX_TOKENS=8000` - Max response length
- `GPT_TEMPERATURE=0.7` - Sampling temperature

## 🐳 Docker

### Build Image

```bash
docker build -t ai-app-backend:latest .
```

### Run Container

```bash
docker run -p 8000:8000 \
  -e AZURE_OPENAI_ENDPOINT=... \
  -e AZURE_OPENAI_API_KEY=... \
  ai-app-backend:latest
```

### Docker Compose

```bash
docker-compose up backend
```

## 📚 Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [Azure OpenAI Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [GPT-5.2 Guide](../docs/gpt52-integration.md)

---

**Built with Python 3.12, FastAPI, LangGraph, and Azure AI Services**
