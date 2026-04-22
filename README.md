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
- AWS deployment scaffold: Terraform for ECS/ALB/WAF/RDS under `terraform/`

## Configuration

Environment variables are defined in [.env.example](.env.example). Key variables:

- `DATABASE_URL` (required)
- `APP_NAME`, `DEBUG`
- `HOST`, `PORT`, `WEB_PORT`
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT`

Never commit `.env` with real credentials.

## AWS Deployment

The repository now includes a Terraform stack in `terraform/` for deploying the app to AWS with:

- **ECS on EC2** as the recommended default, with **Fargate** supported through `ecs_launch_type`
- **Application Load Balancer** with health checks against `GET /health`
- **AWS WAFv2** with a basic managed-rule baseline and rate limiting
- **Amazon RDS for PostgreSQL** in private subnets
- **CloudWatch Logs** and baseline alarms
- **ECR (recommended)** or **Docker Hub** image registry support

### Terraform inputs

Copy `terraform/terraform.tfvars.example` to a non-committed `.tfvars` file and set at least:

- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`
- `db_subnet_ids` (or let it fall back to the private subnets)
- `ecs_launch_type` (`EC2` recommended, `FARGATE` supported)
- `container_registry_type` (`ecr` recommended, `dockerhub` supported)

Optional production-oriented inputs:

- `acm_certificate_arn`, `route53_zone_id`, `domain_name` for HTTPS and DNS
- `alarm_topic_arn` for notifications
- `allowed_ingress_cidrs` to restrict public ingress

### Bootstrap and deploy

1. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   ```
2. Review the plan:
   ```bash
   terraform plan -var-file=your-environment.tfvars
   ```
3. Apply the stack:
   ```bash
   terraform apply -var-file=your-environment.tfvars
   ```
4. Build and push the container image using either:
   - the included GitHub Actions workflow: `.github/workflows/aws-ecs-deploy.yml`
   - or your own `docker build` / `docker push` flow
5. Trigger a fresh deployment so ECS pulls the pushed image:
   ```bash
   aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment
   ```

### IAM and secret handling

- **ECS on EC2** uses an **instance profile** for node-level AWS access.
- ECS tasks use a dedicated **task execution role** for image pulls, CloudWatch logs, and Secrets Manager access.
- The generated RDS credentials and `DATABASE_URL` are stored in **AWS Secrets Manager** and injected into the task at runtime.

### Delivery tooling guidance

- **Recommended:** GitHub Actions + Terraform for ECS delivery.
- **Not recommended as the primary path:** Argo CD, because this stack targets **ECS**, not **EKS/Kubernetes**.
- If you later move to EKS, Argo CD becomes a reasonable GitOps choice.

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
terraform/   # AWS ECS/ALB/WAF/RDS infrastructure
tests/       # test suite
.github/
	workflows/ # CI workflows
```

## Development Guidelines

Project coding/security guidance is documented in [.github/copilot-instructions.md](.github/copilot-instructions.md).
