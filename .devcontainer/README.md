# Dev Container Reference

For the user-facing setup flow, use [setup/dev-container/README.md](../setup/dev-container/README.md).

This file documents Dev Container-specific behavior in this repository.

## Container Configuration Summary

- Primary service: `web` (from root `docker-compose.yml`)
- Compose files used by Dev Containers:
  - `../docker-compose.yml`
  - `./docker-compose.yml` (override)
- Workspace mount: repository mounted under `/workspaces/...`
- Forwarded ports: `8000` (API), `5432` (PostgreSQL)

## Runtime Behavior in Dev Container

- The override sets `command: sleep infinity` so the container stays running for interactive development.
- Start the API manually from the container terminal:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

- Environment defaults are loaded from `.env.example` via Compose in this setup.

## Tooling Included for IDE Analysis

- Python (runtime and language tooling)
- Java 17 feature (required by SonarQube for IDE language server)
- Node.js 22 feature (required by SonarQube for IDE JS/TS analysis)
- VS Code extensions include:
  - `ms-python.python`
  - `ms-python.vscode-pylance`
  - `SonarSource.sonarlint-vscode`

## Troubleshooting

- If Sonar analysis does not start, verify:

```bash
java -version
node -v
```

- If Dev Container config changes are not applied, run:
  - `Dev Containers: Rebuild Container`
