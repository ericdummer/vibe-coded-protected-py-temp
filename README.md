# Vibe Coded Protected

FastAPI + PostgreSQL reference project focused on secure defaults, clear configuration, and CI security checks.

## Start Here

For all setup, run, test, and troubleshooting commands, use [SETUP.md](SETUP.md).

- Quick setup and first run: [SETUP.md](SETUP.md)
- Local and Docker test commands: [SETUP.md](SETUP.md)
- Troubleshooting common issues: [SETUP.md](SETUP.md)

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
- [pip-audit.yml](.github/workflows/pip-audit.yml): dependency vulnerability audit with PR markdown report
- [trivy.yml](.github/workflows/trivy.yml): filesystem and container vulnerability scans
- [codeql.yml](.github/workflows/codeql.yml): CodeQL analysis

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
