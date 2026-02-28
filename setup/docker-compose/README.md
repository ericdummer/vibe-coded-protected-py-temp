# Docker Compose Setup

Use this path when you want to run the API and PostgreSQL together in containers.

## Prerequisites

- Docker Engine or Docker Desktop
- Docker Compose (`docker compose`)

## 1) Start services

From the repository root:

```bash
docker compose up --build
```

This starts:

- `web` (FastAPI app)
- `db` (PostgreSQL)

## 2) Verify

- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health: http://localhost:8000/health

## 3) Stop services

```bash
docker compose down
```

Remove volumes (including local DB data):

```bash
docker compose down -v
```

## Useful commands

Run tests in the container:

```bash
docker compose run web pytest
```

View logs:

```bash
docker compose logs -f web
docker compose logs -f db
```

Back to setup index: [SETUP.md](../../SETUP.md)
Back to project overview: [README.md](../../README.md)