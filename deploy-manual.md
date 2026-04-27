# Manual Deploy Steps

## Variables — Set These Before Running Commands

```
export AWS_REGION=us-west-2
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REPO=startup
export CLUSTER=<your-ecs-cluster-name>
export SERVICE=<your-ecs-service-name>
export ASG_NAME=<your-asg-name>
export TASK_FAMILY=<your-task-definition-family>
```

---

## Before You Start — Navigate to the Right Directory

All commands assume you are in the `terraform/` directory:

```
cd terraform
```

---

## Step 1 — Apply Terraform Changes (infra only, no app code change)

```
terraform apply -var-file=dev.tfvars
```

---

## Step 2 — If you changed instance type, AMI, or user data: refresh ASG instances

```
aws autoscaling start-instance-refresh --auto-scaling-group-name $ASG_NAME --region $AWS_REGION
```

Check refresh status (run until Status is "Successful"):
```
aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --region $AWS_REGION --query "InstanceRefreshes[0].{Status:Status,Percent:PercentageComplete}"
```

Verify new instance registered with ECS (should show 1 ARN):
```
aws ecs list-container-instances --cluster $CLUSTER --region $AWS_REGION
```

---

## Step 3 — If you changed app code: build and push a new Docker image

Authenticate Docker to ECR:
```
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

Capture the git SHA (run from project root, not terraform/):
```
SHA=$(git rev-parse HEAD)
```

Build with both tags:
```
docker build --platform linux/amd64 -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$SHA -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest ..
```

Push both tags:
```
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$SHA
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest
```

---

## Step 4 — Apply Terraform with the SHA so the task definition references the exact image

```
terraform apply -var-file=dev.tfvars -var="container_image_tag=$SHA"
```

---

## Step 5 — Force ECS to deploy the new task definition

```
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment --region $AWS_REGION
```

Check task status (run until status is RUNNING):
```
aws ecs describe-tasks --cluster $CLUSTER --region $AWS_REGION --tasks $(aws ecs list-tasks --cluster $CLUSTER --region $AWS_REGION --query "taskArns[0]" --output text) --query "tasks[0].{status:lastStatus,health:healthStatus,reason:stoppedReason}"
```

---

## When to Run Each Step

| Scenario | Steps |
|---|---|
| Changed instance type / AMI / user data | 1, 2, 5 |
| Changed app code only | 3, 4, 5 |
| Changed other Terraform (ALB, RDS, etc) | 1 only |
| Full fresh deploy | 1, 2, 3, 4, 5 |

---

## Rollback to a Previous Version

List recent task definition revisions:
```
aws ecs list-task-definitions --family-prefix $TASK_FAMILY --region $AWS_REGION --sort DESC
```

Roll back to a specific revision (e.g. revision 3) — no rebuild needed:
```
aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $TASK_FAMILY:3 --region $AWS_REGION
```
