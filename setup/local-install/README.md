# Local Install Setup

Use this path when you want to run everything directly on your machine (without Docker).

## Prerequisites

- Python 3.11+
- `pip`
- Optional: PostgreSQL (if you want a PostgreSQL-backed local run)

## 1) Create and activate a virtual environment (optional, recommended)

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 2) Install dependencies

```bash
pip install -r requirements.txt
```

## 3) Configure environment variables

Copy the example env file and edit it with your values:

```bash
cp .env.example .env
```

Minimum required variable:

- `DATABASE_URL`

Example using local PostgreSQL:

```bash
export POSTGRES_USER="vibeuser"
export POSTGRES_PASSWORD="vibepass"
export POSTGRES_DB="vibedb"
export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}"
export DEBUG="true"
```

## 4) Start the app

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 5) Verify

- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health: http://localhost:8000/health

## Run tests

```bash
pytest
```

Back to setup index: [SETUP.md](../../SETUP.md)
Back to project overview: [README.md](../../README.md)