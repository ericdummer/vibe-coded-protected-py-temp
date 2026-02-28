# Vibe Coded Protected

FastAPI + PostgreSQL reference project focused on secure defaults, clear configuration, and CI security checks.

## Start Here

Choose one setup path:

- Local install (optionally with a virtual environment): [setup/local-install/README.md](setup/local-install/README.md)
- Docker Compose: [setup/docker-compose/README.md](setup/docker-compose/README.md)
- VS Code Dev Container: [setup/dev-container/README.md](setup/dev-container/README.md)

For a setup index, see [SETUP.md](SETUP.md).

## Current Application State

- Framework: FastAPI (`app/main.py`)
- Routes: `GET /` and `GET /health` (`app/api/routes.py`)
- Docs: `/docs` (Swagger UI) and `/redoc`
- Runtime config: environment variables via `pydantic-settings` (`app/core/config.py`)
- Local container stack: FastAPI app + PostgreSQL (`docker-compose.yml`)

## Configuration

Environment variables are defined in [.env.example](.env.example). Key variables:

- `DATABASE_URL` (required)
- `APP_NAME`, `DEBUG`
- `HOST`, `PORT`, `WEB_PORT`
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT`

Never commit `.env` with real credentials.

## CI / Security Workflows

GitHub Actions workflows in [.github/workflows](.github/workflows):

- [tests.yml](.github/workflows/tests.yml): unit tests and coverage
- [ruff.yml](.github/workflows/ruff.yml): lint and format checks
- [trivy.yml](.github/workflows/trivy.yml): filesystem and container vulnerability scans
- [codeql.yml](.github/workflows/codeql.yml): CodeQL analysis

## Sonar Configuration

Sonar scanner settings are defined in [sonar-project.properties](sonar-project.properties):

- `sonar.sources=app`: scans application source files under `app/`
- `sonar.tests=tests`: identifies test files under `tests/`
- `sonar.python.version=3.11`: pins analysis to the project Python version
- `sonar.python.coverage.reportPaths=coverage.xml`: imports pytest coverage results

This `sonar.python.version` setting is the recommended fix for the SonarCloud warning about default compatibility with all Python versions.

## Repository Layout

```
app/
	api/       # API routes
	core/      # settings/config
	db/        # database wiring
	models/    # SQLAlchemy models
tests/       # test suite
.github/
	workflows/ # CI workflows
```

## Development Guidelines

Project coding/security guidance is documented in [.github/copilot-instructions.md](.github/copilot-instructions.md).
