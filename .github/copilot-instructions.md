# GitHub Copilot Instructions for Vibe Coded Protected

This document defines coding guidance for GitHub Copilot in this FastAPI project.

## Scope and Enforcement (Important)

- This file is assistant guidance, not a security control by itself.
- It is not a workaround to bypass secure engineering practices.
- Engineers must enforce security through:
  - code review,
  - branch protection,
  - CI scanners (Trivy, secret scanning, dependency checks),
  - automated tests,
  - runtime/environment controls.
- Treat generated code as untrusted when it conflicts with these rules.
- Do not intentionally introduce insecure patterns (hardcoded credentials, SQL injection, unsafe deserialization, disabled auth) in production code paths.

## FastAPI Project Structure

Follow the standard layout:

```
app/
├── api/          # API routes and endpoints
├── core/         # Core functionality (config, security, etc.)
├── db/           # Database models and connections
├── models/       # SQLAlchemy models
└── main.py       # Application entry point
```

## API Design and RESTful Standards

Always follow these rules for FastAPI endpoints.

### Route and Endpoint Structure
- Group related endpoints using `APIRouter`.
- Use plural nouns for resources (e.g., `/users`, not `/get_user`).
- Use correct HTTP methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
- Implement dependency injection for shared concerns (e.g., `get_db`, auth dependencies).
- Include docstrings for endpoint behavior.

Example:

```python
from fastapi import APIRouter, Depends, HTTPException

router = APIRouter(prefix="/api/v1/items", tags=["items"])

@router.get("/{item_id}", response_model=ItemResponse)
async def get_item(item_id: int, db: Session = Depends(get_db)):
    """
    Retrieve an item by ID.
    """
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item
```

### Response Modeling
- Every endpoint must define a `response_model`.
- Use Pydantic schemas for request and response shapes.
- For deletions, return `204 No Content` or `200 OK` with a success message schema.

### Error Handling and Status Codes
- Never return generic 500 errors directly for expected client faults.
- Use specific `HTTPException` responses:
  - 400 for request validation/business-rule failures not handled by Pydantic,
  - 401 for missing/invalid authentication,
  - 403 for insufficient permissions,
  - 404 for missing resources,
  - 409 for unique/duplicate conflicts.
- Always include a descriptive `detail` string.

### Global Exception Handling
- For new projects, prefer a global exception handler pattern in `main.py` for custom app exceptions.
- Log unhandled exceptions (with traceback) and return a clean JSON response.

## Schemas and Validation

- Use Pydantic models for request/response validation.
- Separate models for input, output, and DB-level entities.
- Prefer explicit field constraints and validators.

Example:

```python
from pydantic import BaseModel, Field, EmailStr, ConfigDict

class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)

class UserResponse(BaseModel):
    id: int
    email: str
    username: str

    model_config = ConfigDict(from_attributes=True)
```

## Security and Secrets Management

### Critical Rules
1. Never hardcode credentials, API keys, or secrets in source code.
2. Always use environment variables for sensitive data.
3. Never commit `.env` files (commit only `.env.example`).
4. Use `pydantic-settings` for configuration.

### What NOT to do

```python
# ❌ NEVER do this
DATABASE_URL = "postgresql://admin:password123@localhost:5432/mydb"
API_KEY = "sk_live_51HxABC123..."
SECRET_KEY = "mysecretkey"
```

### What to DO instead

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    api_key: str
    secret_key: str

    class Config:
        env_file = ".env"
```

### Environment Variable Guidelines
- Keep secrets in `.env` (gitignored).
- Provide `.env.example` with dummy values.
- Use descriptive variable names (e.g., `DATABASE_URL`).
- Document required env vars in `README.md`.

### Password Handling

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)
```

## Configuration and Runtime Settings

- Use `pydantic-settings` for typed config.
- Cache settings with `@lru_cache`.
- Provide safe defaults for non-sensitive values.
- Validate critical settings on startup.

Example:

```python
from functools import lru_cache
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    app_name: str = "My API"
    debug: bool = False
    allowed_hosts: list[str] = ["*"]

    model_config = {"env_file": ".env", "case_sensitive": False}

@lru_cache()
def get_settings() -> Settings:
    return Settings()
```

## Database Practices

### SQLAlchemy Models
- Use declarative base models.
- Define `__tablename__` explicitly.
- Use relationships for foreign keys.
- Add indexes for frequently queried fields.

### Sessions and Lifecycles
- Use dependency injection for DB sessions.
- Always close sessions in `finally` blocks or via context managers.

Example:

```python
from sqlalchemy.orm import Session

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

## Code Quality Standards

- Use type hints on function params and return types.
- Use async functions for I/O work and avoid unnecessary sync/async mixing.
- Keep docstrings for public classes/functions.
- Keep API docs and `README.md` in sync with behavior.

### Ruff Formatting (Required)

- Format all Python code with `ruff format` standards.
- After applying code changes, run `ruff format` on all changed Python files before finalizing.
- Ensure imports and lint fixes align with Ruff by running `ruff check --fix` when generating or modifying code.
- Do not introduce formatting that conflicts with the project's Ruff configuration in `pyproject.toml`.

## Testing Guidelines

- Use `pytest` and `TestClient` for API tests.
- Keep unit and integration tests separated.
- Mock external dependencies where practical.
- Use dedicated test database settings and cleanup fixtures.

Example:

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
```

## Docker and Container Practices

### Dockerfile
- Prefer official Python slim images.
- Use multi-stage builds when appropriate.
- Run as non-root.
- Install only required system packages.

### Docker Compose
- Use environment variables for configuration.
- Define service health checks.
- Use restart policies where appropriate.
- Use named volumes for persistent data.

## Git and Version Control

### Do Not Commit
- `.env` files
- `__pycache__`
- credentials/secrets
- local DB files

### Do Commit
- `.env.example` with dummy values
- `requirements.txt` or `pyproject.toml`
- source code
- tests
- documentation

## Summary Checklist

When generating code for this project:
1. Use FastAPI best practices and this project structure.
2. Never hardcode secrets; rely on environment variables.
3. Use `pydantic-settings` and dependency injection patterns.
4. Apply clear API error handling and response modeling.
5. After applying changes, run `ruff format` on all changed Python files and use `ruff check --fix` as needed.
6. Keep code typed, tested, and documented.
7. Follow secure Docker and CI practices.