# Quick Start: PostgreSQL Migration

## 🚀 Test Locally in 5 Minutes

### Step 1: Start PostgreSQL
```bash
docker run -d \
  --name postgres-dev \
  -e POSTGRES_USER=chatapp \
  -e POSTGRES_PASSWORD=devpassword \
  -e POSTGRES_DB=chatdb \
  -p 5432:5432 \
  postgres:15-alpine
```

### Step 2: Configure Environment
Create/update `.env` in backend folder:
```bash
DATABASE_TYPE=postgresql
POSTGRESQL_HOST=localhost
POSTGRESQL_PORT=5432
POSTGRESQL_DATABASE=chatdb
POSTGRESQL_USER=chatapp
POSTGRESQL_PASSWORD=devpassword
POSTGRESQL_SSL_MODE=disable
```

### Step 3: Run Migrations
```bash
cd backend
.\.venv\Scripts\Activate.ps1
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head
```

### Step 4: Test
```bash
# Run tests
pytest tests/unit/test_postgresql_repository.py -v

# Start application
python -m uvicorn app.main:app --reload

# Test endpoint
curl http://localhost:8000/api/v1/health
```

---

## 🔄 Switch Between Databases

### Use PostgreSQL
```bash
DATABASE_TYPE=postgresql
```

### Use CosmosDB (Original)
```bash
DATABASE_TYPE=cosmosdb
```

**No code changes needed!** Just restart the application.

---

## 🧪 Quick Test

```bash
# Test chat endpoint with thinking steps
curl -X POST http://localhost:8000/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Test message"}
    ],
    "show_thinking": true,
    "stream": false
  }'
```

Messages with thinking steps are now stored in PostgreSQL JSONB column!

---

## 📋 Implementation Summary

### ✅ What's Done
- SQLAlchemy models (Conversation, Message, User)
- Repository pattern (PostgreSQL + CosmosDB)
- Factory for database selection
- Alembic migrations setup
- Application updated to use repositories
- Unit tests created

### ⏳ What's Next
- Start PostgreSQL locally
- Run migrations
- Execute tests
- Deploy to Azure

---

## 🐘 Check Database

```bash
# Connect to PostgreSQL
docker exec -it postgres-dev psql -U chatapp -d chatdb

# Check tables
\dt

# Query conversations
SELECT * FROM conversations;

# Query messages (with thinking steps)
SELECT id, role, content, thinking_steps FROM messages;

# Exit
\q
```

---

## 🔧 Troubleshooting

### "Can't connect to PostgreSQL"
- Check Docker is running: `docker ps`
- Check port 5432 is free: `netstat -an | findstr 5432`

### "Alembic command not found"
- Activate venv: `.\.venv\Scripts\Activate.ps1`
- Install alembic: `pip install alembic==1.13.1`

### "Module not found"
- Check you're in backend directory
- Activate venv first

---

**Ready to test!** 🎉
