# Using This Project in VS Code Dev Containers

Use this guide when you want VS Code to run the project inside a Dev Container instead of running commands directly on your host machine.

## Prerequisites

- Docker Desktop (or Docker Engine) running
- Visual Studio Code
- VS Code extension: `Dev Containers` (`ms-vscode-remote.remote-containers`)

## Open in a Dev Container

1. Open this repository in VS Code.
2. Run Command Palette (`Cmd+Shift+P` on macOS, `Ctrl+Shift+P` on Linux/Windows).
3. Select `Dev Containers: Reopen in Container`.
4. Wait for the container build/start to complete.

## Start the App Inside the Container

In the VS Code terminal (inside the container):

```bash
cp .env.example .env
docker compose up --build
```

Then open:

- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

## SonarQube for IDE Notes

This Dev Container installs Java and Node because SonarQube for IDE needs:

- Java for the language server runtime
- Node.js for JavaScript/TypeScript analysis

If Sonar analysis does not start, run:

```bash
java -version
node -v
```

## Rebuild After Config Changes

If `.devcontainer/devcontainer.json` changes, run:

- `Dev Containers: Rebuild Container`
