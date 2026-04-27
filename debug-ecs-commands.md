# ECS Debug Commands

## Variables — Set These Before Running Commands

```
export AWS_REGION=us-west-2
export CLUSTER=<your-ecs-cluster-name>
export SERVICE=<your-ecs-service-name>
export ASG_NAME=<your-asg-name>
export TASK_FAMILY=<your-task-definition-family>
export LOG_GROUP=<your-cloudwatch-log-group>
export NAME_PREFIX=<your-project-name-prefix>
```

---

## Service Health

List services and desired/running/pending counts:
```
aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query "services[0].{status:status,desired:desiredCount,running:runningCount,pending:pendingCount}"
```

Last 10 service events (shows placement failures, deployments, health check failures):
```
aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query "services[0].events[:10]"
```

---

## Tasks

List running task ARNs:
```
aws ecs list-tasks --cluster $CLUSTER --region $AWS_REGION
```

List stopped task ARNs:
```
aws ecs list-tasks --cluster $CLUSTER --desired-status STOPPED --region $AWS_REGION
```

Describe the most recent task (status, health, stop reason):
```
aws ecs describe-tasks --cluster $CLUSTER --region $AWS_REGION --tasks $(aws ecs list-tasks --cluster $CLUSTER --region $AWS_REGION --query "taskArns[0]" --output text) --query "tasks[0].{status:lastStatus,health:healthStatus,reason:stoppedReason,container:containers[0].{exit:exitCode,reason:reason}}"
```

Describe the most recent STOPPED task (useful after a crash):
```
aws ecs describe-tasks --cluster $CLUSTER --region $AWS_REGION --tasks $(aws ecs list-tasks --cluster $CLUSTER --desired-status STOPPED --region $AWS_REGION --query "taskArns[0]" --output text) --query "tasks[0].{status:lastStatus,reason:stoppedReason,container:containers[0].{exit:exitCode,reason:reason}}"
```

---

## Container Instances (EC2 only)

List registered container instances:
```
aws ecs list-container-instances --cluster $CLUSTER --region $AWS_REGION
```

Describe container instances (CPU/memory available vs reserved):
```
aws ecs describe-container-instances --cluster $CLUSTER --region $AWS_REGION --container-instances $(aws ecs list-container-instances --cluster $CLUSTER --region $AWS_REGION --query "containerInstanceArns[0]" --output text) --query "containerInstances[0].{status:status,agent:agentConnected,runningTasks:runningTasksCount,cpu:remainingResources[0],memory:remainingResources[1]}"
```

---

## Auto Scaling Group

List instances and their types/states:
```
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --region $AWS_REGION --query "AutoScalingGroups[0].Instances[*].{id:InstanceId,type:InstanceType,state:LifecycleState,health:HealthStatus}"
```

Check instance refresh status:
```
aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --region $AWS_REGION --query "InstanceRefreshes[0].{Status:Status,Percent:PercentageComplete,Reason:StatusReason}"
```

Recent scaling activity (spot failures, launch errors):
```
aws autoscaling describe-scaling-activities --auto-scaling-group-name $ASG_NAME --region $AWS_REGION --query "Activities[:5].{Status:StatusCode,Cause:Cause}"
```

Trigger instance refresh (after launch template change):
```
aws autoscaling start-instance-refresh --auto-scaling-group-name $ASG_NAME --region $AWS_REGION
```

---

## CloudWatch Logs

List log streams (most recent first):
```
aws logs describe-log-streams --log-group-name $LOG_GROUP --region $AWS_REGION --order-by LastEventTime --descending --query "logStreams[:5].logStreamName"
```

Tail the most recent log stream:
```
aws logs get-log-events --log-group-name $LOG_GROUP --region $AWS_REGION --log-stream-name $(aws logs describe-log-streams --log-group-name $LOG_GROUP --region $AWS_REGION --order-by LastEventTime --descending --query "logStreams[0].logStreamName" --output text) --query "events[*].message"
```

---

## ALB Target Health

List target group ARN:
```
aws elbv2 describe-target-groups --region $AWS_REGION --query "TargetGroups[?contains(TargetGroupName, '$NAME_PREFIX')].TargetGroupArn"
```

Check target health (shows which tasks are healthy/unhealthy and why):
```
aws elbv2 describe-target-health --region $AWS_REGION --target-group-arn $(aws elbv2 describe-target-groups --region $AWS_REGION --query "TargetGroups[?contains(TargetGroupName, '$NAME_PREFIX')].TargetGroupArn" --output text) --query "TargetHealthDescriptions[*].{target:Target.Id,port:Target.Port,state:TargetHealth.State,reason:TargetHealth.Reason,description:TargetHealth.Description}"
```

---

## Secrets Manager

Check if secrets exist (useful after terraform destroy/apply):
```
aws secretsmanager list-secrets --region $AWS_REGION --query "SecretList[?contains(Name, '$NAME_PREFIX')].{Name:Name,DeletedDate:DeletedDate}"
```

---

## Quick Status Summary

Run all at once for a full snapshot:
```
echo "=== SERVICE ===" && aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION --query "services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}" && echo "=== TASKS ===" && aws ecs list-tasks --cluster $CLUSTER --region $AWS_REGION && echo "=== CONTAINER INSTANCES ===" && aws ecs list-container-instances --cluster $CLUSTER --region $AWS_REGION && echo "=== ASG ===" && aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --region $AWS_REGION --query "AutoScalingGroups[0].Instances[*].{id:InstanceId,type:InstanceType,state:LifecycleState}"
```
