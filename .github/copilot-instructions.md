# GitHub Copilot Instructions for Vibe Coded Protected

This document provides guidelines for GitHub Copilot to help maintain code quality, security, and best practices in this FastAPI project.

## FastAPI Structure and Best Practices

### Application Architecture
- Follow the standard FastAPI project structure:
  ```
  app/
  ├── api/          # API routes and endpoints
  ├── core/         # Core functionality (config, security, etc.)
  ├── db/           # Database models and connections
  ├── models/       # SQLAlchemy models
  └── main.py       # Application entry point
  ```

### Route Organization
- Group related endpoints using `APIRouter`
- Use proper HTTP methods (GET, POST, PUT, DELETE, PATCH)
- Apply appropriate status codes for responses
- Use dependency injection for database sessions and authentication
- Always include docstrings for endpoints

Example:
```python
from fastapi import APIRouter, Depends, HTTPException, status

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

### Pydantic Models
- Use Pydantic models for request/response validation
- Separate models for requests, responses, and database operations
- Use `BaseModel` for data validation
- Leverage Pydantic's built-in validators

Example:
```python
from pydantic import BaseModel, Field, EmailStr

class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    
class UserResponse(BaseModel):
    id: int
    email: str
    username: str
    
    class Config:
        from_attributes = True
```

## Security: NEVER Store Credentials in Code

### Critical Security Rules
1. **NEVER hardcode credentials, API keys, or secrets in source code**
2. **ALWAYS use environment variables for sensitive data**
3. **NEVER commit `.env` files to version control** (only commit `.env.example`)
4. **Use pydantic-settings for configuration management**

### What NOT to do:
```python
# ❌ NEVER do this - hardcoded credentials
DATABASE_URL = "postgresql://admin:password123@localhost:5432/mydb"
API_KEY = "sk_live_51HxABC123..."
SECRET_KEY = "mysecretkey"
```

### What to DO instead:
```python
# ✅ ALWAYS do this - use environment variables
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str  # Will be loaded from environment
    api_key: str
    secret_key: str
    
    class Config:
        env_file = ".env"
```

### Environment Variable Guidelines
- Store all secrets in `.env` file (which is in `.gitignore`)
- Provide `.env.example` with dummy values as a template
- Use descriptive environment variable names (e.g., `DATABASE_URL`, not `DB`)
- Document all required environment variables in README

### Secure Password Handling
```python
from passlib.context import CryptContext

# ✅ Use proper password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)
```

## Configuration Best Practices

### Settings Management
- Use `pydantic-settings` for type-safe configuration
- Cache settings using `@lru_cache` to avoid repeated reads
- Provide sensible defaults for non-sensitive settings
- Use dependency injection to access settings

Example:
```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # Required settings (no defaults)
    database_url: str
    secret_key: str
    
    # Optional settings with defaults
    app_name: str = "My API"
    debug: bool = False
    allowed_hosts: list[str] = ["*"]
    
    class Config:
        env_file = ".env"
        case_sensitive = False

@lru_cache()
def get_settings() -> Settings:
    return Settings()

# Usage in routes
from fastapi import Depends

@app.get("/info")
async def info(settings: Settings = Depends(get_settings)):
    return {"app_name": settings.app_name}
```

### Environment-Specific Configuration
- Use different `.env` files for different environments
- Never commit production `.env` files
- Validate required settings on startup

```python
# Validate settings on startup
@app.on_event("startup")
async def validate_config():
    settings = get_settings()
    if not settings.database_url:
        raise ValueError("DATABASE_URL must be set")
```

## Database Best Practices

### SQLAlchemy Models
- Use declarative base for models
- Always define `__tablename__` explicitly
- Use relationship() for foreign keys
- Add indexes for frequently queried fields

```python
from sqlalchemy import Column, Integer, String, Index
from app.db.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
```

### Database Sessions
- Use dependency injection for database sessions
- Always close sessions in finally blocks
- Use context managers when possible

```python
from fastapi import Depends
from sqlalchemy.orm import Session

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Usage
@router.get("/users")
async def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()
```

## Error Handling

### HTTP Exceptions
- Use FastAPI's HTTPException for API errors
- Provide clear, user-friendly error messages
- Use appropriate HTTP status codes

```python
from fastapi import HTTPException, status

@router.get("/users/{user_id}")
async def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    return user
```

## Testing Guidelines

### Test Structure
- Use pytest for testing
- Use TestClient for API testing
- Separate unit tests from integration tests
- Mock external dependencies

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
```

### Test Database
- Use a separate test database
- Clean up test data after each test
- Use fixtures for common setup

## Code Quality Standards

### Type Hints
- Always use type hints for function parameters and return values
- Use `Optional` for nullable values
- Use `Union` for multiple possible types

```python
from typing import Optional, List

async def get_user_by_email(
    email: str, 
    db: Session
) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()
```

### Async/Await
- Use async functions for I/O operations
- Use `await` for async database queries when using async drivers
- Don't mix sync and async unnecessarily

### Documentation
- Include docstrings for all public functions and classes
- Document API endpoints with clear descriptions
- Keep README.md up to date

## Docker Best Practices

### Dockerfile
- Use official Python slim images
- Run as non-root user
- Use multi-stage builds when appropriate
- Don't install unnecessary packages

### Docker Compose
- Use environment variables for configuration
- Use health checks for services
- Define proper restart policies
- Use named volumes for persistence

## Git and Version Control

### What NOT to Commit
- Never commit `.env` files
- Never commit `__pycache__` directories
- Never commit credentials or secrets
- Never commit local database files

### What to Commit
- `.env.example` with dummy values
- `requirements.txt` or `pyproject.toml`
- All source code
- Tests
- Documentation

## Summary

When writing code for this project, GitHub Copilot should:
1. ✅ Use FastAPI best practices and proper structure
2. ✅ NEVER hardcode credentials - always use environment variables
3. ✅ Use pydantic-settings for configuration management
4. ✅ Implement proper error handling and validation
5. ✅ Write type-safe code with type hints
6. ✅ Include comprehensive tests
7. ✅ Follow security best practices
8. ✅ Document code with clear docstrings
9. ✅ Use dependency injection patterns
10. ✅ Handle database sessions properly
