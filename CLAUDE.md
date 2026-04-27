# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FastAPI + PostgreSQL reference project with AWS ECS deployment infrastructure. The app layer is intentionally minimal — the bulk of complexity lives in the Terraform infrastructure and CI/CD pipelines.

## Commands

**Run locally:**
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Run with Docker Compose (recommended):**
```bash
docker compose up --build
docker compose down -v  # tear down including volumes
docker compose run web pytest  # run tests inside container
```

**Tests:**
```bash
pytest                                              # all tests
pytest tests/test_api.py -v                        # single file
pytest --cov=app --cov-report=term-missing         # with coverage
pytest -m "not slow and not integration"           # skip slow/integration
```

**Lint & format:**
```bash
ruff check .           # lint
ruff format --check .  # format check
ruff check --fix .     # auto-fix lint
ruff format .          # auto-format
```

After any Python changes, run `ruff format` on changed files and `ruff check --fix` before finalizing.

## Architecture

```
app/
├── main.py          # FastAPI app instance, lifespan hooks
├── api/routes.py    # All endpoints (grouped by APIRouter)
├── core/config.py   # Pydantic Settings (cached with @lru_cache)
├── db/database.py   # SQLAlchemy engine, SessionLocal, get_db() dependency
└── models/          # SQLAlchemy ORM models

tests/
├── conftest.py      # TestClient fixture, Settings overrides
├── test_api.py      # Endpoint tests
└── test_config.py   # Config tests

terraform/           # AWS ECS/ALB/RDS/WAF/IAM infrastructure
.github/workflows/   # CI: tests, ruff, CodeQL, Trivy, ECS deploy
```

**Request flow:** ALB → WAFv2 → ECS (Fargate or EC2) → FastAPI → RDS PostgreSQL (private subnet)

**Database:** SQLAlchemy with `pool_pre_ping=True`. Supports both standard `DATABASE_URL` and AWS RDS IAM authentication (set `db_iam_auth=true` in env). Session lifecycle via `get_db()` dependency injection — always `yield` from a `try/finally`.

**Configuration:** `app/core/config.py` uses `pydantic-settings` with `@lru_cache`. All secrets come from environment variables; never hardcode them. Supports optional `.env` file (disable with `PYTHON_DOTENV_DISABLED=1`).

## API Conventions

- Group endpoints with `APIRouter(prefix="/api/v1/...", tags=[...])`
- Every endpoint must declare `response_model`
- Use separate Pydantic schemas for input, output, and DB entities; add `model_config = ConfigDict(from_attributes=True)` on response schemas
- HTTP status codes: 400 bad request, 401 unauthenticated, 403 forbidden, 404 not found, 409 conflict — never expose raw 500s for expected failures
- Use `async def` for all I/O endpoints; add type hints and docstrings to public functions

## Infrastructure (Terraform)

All infrastructure is in `terraform/`. Use the provided `.tfvars.example` files as templates. The deploy workflow (`aws-ecs-deploy.yml`) is `workflow_dispatch` only — it builds the Docker image, pushes to ECR or Docker Hub, then runs `terraform plan`/`apply`, and updates the ECS service.

Bootstrap a new AWS environment with `bootstrap-aws/create-vpc.sh` before running Terraform.

## Environment Variables

Copy `.env.example` to `.env` for local development. Key vars:

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Full PostgreSQL connection string |
| `DEBUG` | Enables debug mode |
| `db_iam_auth` | Use AWS RDS IAM auth instead of password |
| `aws_region` | AWS region for RDS IAM token |

## Manual Deployment (ECS)

Use this when you've already run `terraform apply` locally and just need to ship new code.

**1. Authenticate Docker to ECR:**
```bash
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 490004643609.dkr.ecr.us-west-2.amazonaws.com
```

**2. Build and push the image:**
```bash
SHA=$(git rev-parse HEAD)
ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)
docker build -t "$ECR_URL:$SHA" .
docker push "$ECR_URL:$SHA"
```

**3. Force a new ECS deployment:**
```bash
CLUSTER=$(cd terraform && terraform output -raw ecs_cluster_name)
SERVICE=$(cd terraform && terraform output -raw ecs_service_name)
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment --region us-west-2
```

The app will be live at the ALB URL (`terraform output alb_dns_name`) once the new task reaches running state (~1–2 min).

## CI Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `tests.yml` | push/PR to main, develop | pytest with PostgreSQL service |
| `ruff.yml` | push/PR to main, develop | lint + format check |
| `codeql.yml` | scheduled + push | static security analysis |
| `trivy.yml` | push | container vulnerability scan |
| `aws-ecs-deploy.yml` | manual | build, push image, Terraform, deploy |
