# Copilot Instructions — Azure AI Chat Application

## Architecture Overview

Three-tier app: **Next.js 16 frontend** → **FastAPI + LangGraph backend** → **Azure AI services** (GPT-5.2, AI Search, Cosmos DB). Deployed on AKS with Envoy Gateway API. Infrastructure managed via Terraform workspaces (dev/sit/uat/prod) and Helm charts.

**Data flow**: User → SSE stream from `POST /api/v1/chat/completions` → `ChatGraph.stream_chat()` (LangGraph) → `OpenAIService.stream_chat_with_thinking()` (Azure OpenAI Responses API) → yields `StreamChunk` objects (type: thinking|content|done|error) back as `data: {json}\n\n` events.

## Backend (Python — `backend/`)

- **Framework**: FastAPI with Pydantic v2, async endpoints, lifespan context manager
- **AI Orchestration**: LangGraph `StateGraph` workflows in `app/graphs/` — three graphs: `ChatGraph` (chat + thinking), `RAGGraph` (retrieve → rank → generate), `AgentGraph` (router → executor → aggregator)
- **OpenAI Integration**: Uses the **Responses API** (not Chat Completions) via `openai` SDK with `DefaultAzureCredential` managed identity. System messages map to `developer` role. Key params: `reasoning` (effort + summary) and `text` (verbosity)
- **Repository Pattern**: Abstract `BaseRepository` → `PostgreSQLRepository` (singleton via `get_repository()` factory in `app/repositories/factory.py`). ORM models use `to_dict()` returning **camelCase keys** for API compatibility
- **Config**: All settings in `app/core/config.py` via `pydantic-settings`, loaded from root `.env` file. Feature flags: `enable_streaming`, `enable_thinking_process`, `enable_rag`, `enable_agents`
- **SSE Streaming**: `StreamingResponse` with `media_type="text/event-stream"`, header `X-Accel-Buffering: no`. GZip middleware is intentionally removed (breaks SSE). DB persistence is fire-and-forget via `asyncio.create_task()`
- **DB Migrations**: Alembic with migrations in `backend/alembic/versions/`. Run from `backend/` directory
- **Logging**: JSON format in production, plain text in dev. Use `get_logger(__name__)` from `app.core.logging`
- **Tests**: pytest with `asyncio_mode = auto`, coverage via `--cov=app`. Fixtures in `tests/conftest.py`

## Frontend (TypeScript — `frontend/`)

- **Framework**: Next.js 16 App Router with Turbopack, React 19, TypeScript 5.6+
- **Styling**: Tailwind CSS 3 + shadcn/ui components (`components/ui/`), HSL CSS variables in `globals.css`, utility `cn()` from `lib/utils.ts`
- **State Management**: React hooks only (no Zustand store). `useChat()` and `useRAG()` hooks own all chat state locally with `AbortController` for cancellation
- **SSE Client**: `lib/stream-client.ts` uses `fetch()` → `TextDecoderStream` → `EventSourceParserStream` → `AsyncGenerator<StreamChunk>`. API calls use Axios (`lib/api-client.ts`); streaming uses raw fetch
- **Typewriter Effect**: `use-word-buffer.ts` — adaptive speed (40ms normal, 10ms catchup at >20 words). Thinking step updates batched via `requestAnimationFrame`
- **Types**: `types/chat.ts` mirrors backend Pydantic models (`ChatMessage`, `StreamChunk`, `ThinkingStep`, `ReasoningEffort`, `Verbosity`)
- **Route Structure**: App Router with route groups `(auth)/` and `(dashboard)/`

## Developer Workflows

```bash
# Local dev (full stack via Docker Compose — backend:8000, frontend:3000, postgres:5432, redis:6379)
docker compose up --build -d

# Backend only
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Frontend only
cd frontend && npm run dev  # uses --turbopack

# Tests
cd backend && pytest tests/ -v                # backend (auto-async)
cd frontend && npm test                        # frontend (Jest + RTL)

# Linting & formatting
cd backend && ruff check app/ tests/ && ruff format app/ tests/
cd frontend && npm run lint && npx tsc --noEmit

# Makefile shortcuts: make dev, make test, make lint, make backend-test, make frontend-test
```

## Key Conventions

1. **New API endpoints** go in `backend/app/api/v1/endpoints/`, registered in `app/api/router.py`
2. **New LangGraph workflows** follow the pattern in `app/graphs/chat_graph.py`: define a `TypedDict` state, create `StateGraph`, add nodes/edges, compile
3. **Pydantic models** for requests/responses in `app/models/schemas.py`; DB models in `app/models/db_models.py` (SQLAlchemy declarative)
4. **Frontend components** follow hierarchy: `components/chat/` for chat-specific, `components/ui/` for shadcn primitives, `components/shared/` for reusable
5. **Streaming endpoints** must return `StreamingResponse` with SSE format, yield `StreamChunk` as JSON, and send a final `done` chunk
6. **Environment config** flows through `pydantic-settings` → `settings` singleton; never read `os.environ` directly
7. **Docker builds** use multi-stage: separate `development` (with hot-reload) and `production` (non-root user, healthcheck) targets
8. **Terraform**: `infra/terraform/` with modules in `modules/`, per-env tfvars in `environments/`. Use `make plan-{env}` / `make apply-{env}`
9. **Helm**: chart at `infra/helm/ai-app/` with per-env values files. Uses Envoy Gateway API
