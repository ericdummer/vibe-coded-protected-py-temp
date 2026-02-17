# Vibe Coded Protected

A FastAPI-based web application demonstrating best practices for secure, maintainable code with automated testing and security scanning.

## Features

- 🚀 **FastAPI**: Modern, fast web framework for building APIs
- 🐘 **PostgreSQL**: Robust relational database
- 🐳 **Docker Compose**: Easy local development environment
- ✅ **GitHub Actions**: Automated unit testing
- 🔒 **Trivy Security Scanning**: Automated vulnerability detection
- 📝 **GitHub Copilot Instructions**: Enforces best practices and security

## Project Structure

```
.
├── app/
│   ├── api/              # API routes and endpoints
│   ├── core/             # Core functionality (config, security)
│   ├── db/               # Database setup and connections
│   ├── models/           # SQLAlchemy database models
│   └── main.py           # Application entry point
├── tests/                # Unit and integration tests
├── .github/
│   ├── workflows/        # GitHub Actions CI/CD
│   └── copilot-instructions.md  # Copilot coding guidelines
├── docker-compose.yml    # Docker services configuration
├── Dockerfile            # Application container definition
├── requirements.txt      # Python dependencies
└── .env.example          # Environment variables template
```

## Prerequisites

- Python 3.11+
- Docker and Docker Compose
- Git

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/ericdummer/vibe-coded-protected.git
cd vibe-coded-protected
```

### 2. Set Up Environment Variables

Copy the example environment file and customize it:

```bash
cp .env.example .env
```

Edit `.env` and update the values as needed. **Never commit the `.env` file to version control!**

### 3. Run with Docker Compose

Start the application and database:

```bash
docker-compose up --build
```

The API will be available at:
- **Application**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **ReDoc Documentation**: http://localhost:8000/redoc

### 4. Run Without Docker (Local Development)

Install dependencies:

```bash
pip install -r requirements.txt
```

Start PostgreSQL (ensure it's running locally), then run:

```bash
# Set required environment variables
export DATABASE_URL="postgresql://user:password@localhost:5432/dbname"

# Run the application
python -m app.main
# or
uvicorn app.main:app --reload
```

## Running Tests

### With Docker

```bash
docker-compose run web pytest tests/ -v
```

### Locally

```bash
# Ensure DATABASE_URL is set for test database
export DATABASE_URL="postgresql://testuser:testpass@localhost:5432/testdb"

# Run tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=term-missing
```

## API Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `GET /docs` - Interactive API documentation (Swagger UI)
- `GET /redoc` - Alternative API documentation (ReDoc)

## GitHub Actions Workflows

### Unit Tests (`tests.yml`)
- Runs on push and pull requests
- Sets up PostgreSQL service
- Executes pytest with coverage reporting
- Uploads coverage to Codecov

### Trivy Security Scan (`trivy.yml`)
- Scans code and Docker images for vulnerabilities
- Runs on push, pull requests, and daily schedule
- Reports findings to GitHub Security tab
- Checks for CRITICAL, HIGH, and MEDIUM severity issues

## Security Best Practices

This project follows strict security guidelines:

### ✅ DO:
- Use environment variables for all sensitive data
- Store credentials in `.env` file (never commit it!)
- Use pydantic-settings for configuration management
- Hash passwords before storing them
- Use parameterized SQL queries (SQLAlchemy handles this)
- Keep dependencies updated
- Review Trivy scan results regularly

### ❌ DON'T:
- Never hardcode credentials, API keys, or secrets in code
- Never commit `.env` files to version control
- Never expose sensitive data in API responses
- Never disable security features for convenience

## GitHub Copilot Instructions

This project includes comprehensive [GitHub Copilot instructions](.github/copilot-instructions.md) that ensure:
- Adherence to FastAPI structure and best practices
- Prevention of credential storage in code
- Proper configuration management with environment variables
- Type safety and validation
- Comprehensive error handling
- Testing standards
- Security-first development

## Configuration

All configuration is managed through environment variables. See `.env.example` for all available options:

- `DATABASE_URL`: PostgreSQL connection string
- `APP_NAME`: Application name
- `DEBUG`: Enable debug mode (true/false)
- `HOST`: Server host (default: 0.0.0.0)
- `PORT`: Server port (default: 8000)

## Contributing

1. Follow the GitHub Copilot instructions in `.github/copilot-instructions.md`
2. Write tests for new features
3. Ensure all tests pass before submitting PR
4. Review Trivy security scan results
5. Never commit credentials or sensitive data

## Development Workflow

1. Create a feature branch
2. Make changes following the Copilot instructions
3. Write/update tests
4. Run tests locally
5. Commit changes (tests and security scans run automatically)
6. Create pull request
7. Review CI results and address any issues

## Troubleshooting

### Database Connection Issues
- Ensure PostgreSQL is running: `docker-compose ps`
- Check DATABASE_URL in `.env` file
- Verify PostgreSQL credentials

### Port Already in Use
- Change `WEB_PORT` in `.env` file
- Or stop the service using the port: `lsof -ti:8000 | xargs kill`

### Docker Build Fails
- Clear Docker cache: `docker-compose down -v`
- Rebuild: `docker-compose up --build`

## License

This project is open source and available under the MIT License.

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [Docker Documentation](https://docs.docker.com/)
- [Trivy Security Scanner](https://github.com/aquasecurity/trivy)
