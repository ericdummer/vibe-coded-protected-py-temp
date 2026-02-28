# Vibe Coded Protected

FastAPI + PostgreSQL reference project focused on secure defaults, clear configuration, and CI security checks.

## Start Here

Choose one setup path:

- Option 1 (standard): use [SETUP.md](SETUP.md) for setup, first run, testing, and troubleshooting.
- Option 2 (VS Code Dev Container): use [.devcontainer/README.md](.devcontainer/README.md) to run everything inside a Dev Container.

## Setup Paths (Quick View)

| Path | Best for | Required manual steps | Defaults source |
|---|---|---|---|
| Standard local (Docker Compose) | Running directly from host shell/IDE | Copy `.env.example` to `.env` and adjust values as needed | `.env` (typically created from `.env.example`) |
| VS Code Dev Container | Isolated, reproducible dev environment | Reopen in container, then run `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload` | `.env.example` loaded by devcontainer compose override |

## SonarQube for IDE (Dev Container)

When using this project in a Dev Container:

- Use the `SonarQube for IDE` extension (`SonarSource.sonarlint-vscode`).
- Authenticate with a SonarCloud token via the extension flow (do not store tokens in repo files).
- Rebuild the container after `.devcontainer/devcontainer.json` changes.

This repository's Dev Container includes:

- Java (required to run SonarQube for IDE language server)
- Node.js (required for JavaScript/TypeScript analysis)
- Environment defaults loaded from `.env.example` via Docker Compose overrides for low-friction local startup (replace with real secrets outside local dev)

If analysis does not start, verify inside the container:

- `java -version`
- `node -v`

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
