# Quick Setup Guide

This guide will help you get started with the Vibe Coded Protected FastAPI application.

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
   
   Edit `.env` and update the values as needed. For local development, the default values in `.env.example` are fine.

3. **Start the application with Docker Compose**:
   ```bash
   docker compose up --build
   ```
   
   This will:
   - Build the FastAPI application container
   - Start PostgreSQL database
   - Start the FastAPI application on http://localhost:8000

4. **Access the application**:
   - API: http://localhost:8000
   - Interactive API docs: http://localhost:8000/docs
   - ReDoc documentation: http://localhost:8000/redoc
   - Health check: http://localhost:8000/health

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

### Stopping the Application

```bash
# Stop Docker Compose services
docker compose down

# Stop and remove volumes (this will delete the database data)
docker compose down -v
```

## GitHub Copilot Instructions

This project includes comprehensive GitHub Copilot instructions in `.github/copilot-instructions.md`. These ensure that:
- Code follows FastAPI best practices
- Credentials are never stored in code
- Environment variables are properly used
- Security standards are maintained

GitHub Copilot will automatically use these instructions when suggesting code.

## GitHub Actions CI/CD

This repository includes automated workflows:

### Unit Tests (`.github/workflows/tests.yml`)
- Runs on every push and pull request
- Sets up PostgreSQL database
- Runs all tests with pytest
- Reports test coverage

### Trivy Security Scan (`.github/workflows/trivy.yml`)
- Scans code and Docker images for vulnerabilities
- Runs on push, pull requests, and daily schedule
- Reports findings to GitHub Security tab

## Project Structure

```
vibe-coded-protected/
├── app/                    # Application code
│   ├── api/               # API routes
│   ├── core/              # Core functionality (config)
│   ├── db/                # Database setup
│   ├── models/            # Database models
│   └── main.py            # Application entry point
├── tests/                 # Test files
├── .github/               # GitHub specific files
│   ├── workflows/         # CI/CD workflows
│   └── copilot-instructions.md  # Copilot guidelines
├── .env.example           # Environment variables template
├── docker-compose.yml     # Docker services
├── Dockerfile             # Application container
├── requirements.txt       # Python dependencies
└── README.md              # Main documentation
```

## Adding New Features

1. **Create a new route** in `app/api/routes.py` or create a new router file
2. **Add tests** in `tests/` directory
3. **Run tests locally** to ensure they pass
4. **Commit and push** - CI/CD will run automatically
5. **Review** Trivy security scan results in GitHub Security tab

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

1. Read the full [README.md](README.md) for detailed documentation
2. Review [GitHub Copilot Instructions](.github/copilot-instructions.md)
3. Check [GitHub Actions workflows](.github/workflows/)
4. Start building your API!

## Support

For issues and questions:
- Check the README.md
- Review GitHub Copilot instructions
- Open an issue on GitHub
