# Quick Setup Guide

This document is the source of truth for local setup, running, testing, and troubleshooting.
For a project overview and architecture summary, see [README.md](README.md).

## First Time Setup

1. **Clone the repository** (if not already done):
   ```bash
   git clone https://github.com/ericdummer/vibe-coded-protected.git
   cd vibe-coded-protected
   ```

2. **Create your environment file**:
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and update values as needed. Local defaults from `.env.example` are suitable for development.

3. **Start the application with Docker Compose**:
   ```bash
   docker compose up --build
   ```
   
   This command builds the FastAPI container and starts both API + PostgreSQL.

4. **Access the application**:
   - API: http://localhost:8000
   - Interactive API docs: http://localhost:8000/docs
   - ReDoc documentation: http://localhost:8000/redoc
   - Health check: http://localhost:8000/health

5. **Stop services when needed**:
   ```bash
   docker compose down
   ```

   Remove volumes too (deletes local DB data):
   ```bash
   docker compose down -v
   ```

## Development Workflow

### Running Tests

**With Docker:**
```bash
docker compose run web pytest tests/ -v
```

**Locally:**
```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variable
export DATABASE_URL="postgresql://testuser:testpass@localhost:5432/testdb"

# Run tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=term-missing
```

### Running the Application Locally (without Docker)

```bash
# Install dependencies
pip install -r requirements.txt

# Set required environment variables
export DATABASE_URL="postgresql://vibeuser:vibepass@localhost:5432/vibedb"

# Run the application
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Security Best Practices

✅ **DO:**
- Use environment variables for all secrets
- Keep `.env` file in `.gitignore`
- Review Trivy scan results regularly
- Follow the GitHub Copilot instructions

❌ **DON'T:**
- Hardcode credentials in code
- Commit `.env` files
- Disable security features
- Store secrets in version control

## Troubleshooting

### Port Already in Use
```bash
# Change port in .env file
WEB_PORT=8001
```

### Database Connection Issues
```bash
# Check if PostgreSQL is running
docker compose ps

# View logs
docker compose logs db

# Restart services
docker compose restart
```

### Docker Build Issues
```bash
# Clean rebuild
docker compose down -v
docker compose up --build
```

## Next Steps

1. Read [README.md](README.md) for project overview and current architecture.
2. Review [GitHub Copilot Instructions](.github/copilot-instructions.md).
3. Check CI workflows in [.github/workflows](.github/workflows).
4. Start building your API.

## Support

For issues and questions:
- Check [README.md](README.md)
- Review [GitHub Copilot Instructions](.github/copilot-instructions.md)
- Open an issue on GitHub
