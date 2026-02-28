# VS Code Dev Container Setup

Use this path when you want an isolated development environment managed by VS Code.

## Prerequisites

- Docker Engine or Docker Desktop
- Visual Studio Code
- `Dev Containers` extension (`ms-vscode-remote.remote-containers`)

## 1) Open in container

1. Open this repository in VS Code.
2. Run `Dev Containers: Reopen in Container` from Command Palette.
3. Wait for container build/start to finish.

## 2) Start the app inside the container

In the container terminal:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 3) Verify

- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health: http://localhost:8000/health

## Notes

- The Dev Container Compose override loads defaults from `.env.example`.
- Container-specific reference details are in [.devcontainer/README.md](../../.devcontainer/README.md).

Back to setup index: [SETUP.md](../../SETUP.md)
Back to project overview: [README.md](../../README.md)