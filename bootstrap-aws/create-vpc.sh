#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDRS=("10.0.1.0/24" "10.0.2.0/24")
PRIVATE_SUBNET_CIDRS=("10.0.101.0/24" "10.0.102.0/24")
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(dirname "$0")"
TERRAFORM_DIR="$(dirname "$0")/../terraform"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }

validate_name() {
  local name="$1" label="$2"
  if [[ -z "${name}" ]]; then
    echo "  Error: ${label} cannot be empty."
    return 1
  elif [[ ! "${name}" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    echo "  Error: ${label} must be lowercase letters, numbers, and hyphens only,"
    echo "         must start and end with a letter or number (e.g. my-project)."
    return 1
  elif [[ ${#name} -gt 32 ]]; then
    echo "  Error: ${label} must be 32 characters or fewer (${#name} given)."
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
read -r -p "AWS region [us-west-2]: " AWS_REGION
AWS_REGION="${AWS_REGION:-us-west-2}"

while true; do
  read -r -p "Project name: " PROJECT_NAME
  validate_name "${PROJECT_NAME}" "project name" && break
done

echo ""
echo "  Environment type:"
echo "    1) SDLC      (dev / staging / prod / etc.)"
echo "    2) Personal  (your username or first name)"
echo ""
ENV_TYPE=""
while true; do
  read -r -p "Enter choice [1/2]: " ENV_TYPE
  case "${ENV_TYPE}" in
    1)
      echo "  Suggested names: dev, staging, prod, qa"
      while true; do
        read -r -p "Environment name: " ENVIRONMENT
        validate_name "${ENVIRONMENT}" "environment name" && break
      done
      break
      ;;
    2)
      echo "  Enter your username or first name (e.g. john, alice)"
      while true; do
        read -r -p "Your name/handle: " ENVIRONMENT
        validate_name "${ENVIRONMENT}" "environment name" && break
      done
      break
      ;;
    *)
      echo "  Please enter 1 or 2."
      ;;
  esac
done

# Production mode: SDLC environments whose name starts with "prod"
IS_PROD=false
if [[ "${ENV_TYPE}" == "1" && "${ENVIRONMENT}" =~ ^prod ]]; then
  IS_PROD=true
fi

# All resources use this prefix
NAME_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"

log "Checking AWS credentials..."
if ! CALLER=$(aws sts get-caller-identity --region "${AWS_REGION}" --output json 2>&1); then
  echo "Error: AWS credentials are not configured or are invalid."
  echo "  Run 'aws configure' or set AWS_PROFILE to fix this."
  echo "  Details: ${CALLER}"
  exit 1
fi
AWS_ACCOUNT=$(echo "${CALLER}" | jq -r '.Account')
AWS_ARN=$(echo "${CALLER}" | jq -r '.Arn')

# One bucket + table per project; key is per-environment
TFSTATE_BUCKET="${PROJECT_NAME}-tfstate-${AWS_ACCOUNT}"
TFSTATE_TABLE="${PROJECT_NAME}-tfstate-lock"
TFSTATE_KEY="${ENVIRONMENT:+${ENVIRONMENT}/}terraform.tfstate"

log "Fetching availability zones in ${AWS_REGION}..."
AZLIST=$(aws ec2 describe-availability-zones \
  --region "${AWS_REGION}" \
  --filters Name=state,Values=available \
  --query 'AvailabilityZones[0:2].ZoneName' \
  --output json)
AZ_A=$(echo "${AZLIST}" | jq -r '.[0]')
AZ_B=$(echo "${AZLIST}" | jq -r '.[1]')

# ---------------------------------------------------------------------------
# Preview & confirmation
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Resources to be created"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  AWS account : ${AWS_ACCOUNT}"
echo "  Identity    : ${AWS_ARN}"
echo "  Region      : ${AWS_REGION}"
echo "  Project     : ${PROJECT_NAME}"
echo "  Environment : ${ENVIRONMENT}$( ${IS_PROD} && echo "  (production mode)" || true )"
echo ""
echo "  VPC  (${NAME_PREFIX})"
echo "    CIDR        : ${VPC_CIDR}"
echo "    Flow logs   : /${NAME_PREFIX}/vpc-flow-logs  (CloudWatch)"
echo ""
echo "  Public subnets (attached to Internet Gateway)"
echo "    ${NAME_PREFIX}-public-${AZ_A}   ${PUBLIC_SUBNET_CIDRS[0]}   (${AZ_A})"
echo "    ${NAME_PREFIX}-public-${AZ_B}   ${PUBLIC_SUBNET_CIDRS[1]}   (${AZ_B})"
echo ""
echo "  Private subnets (no NAT Gateway — AWS service access via VPC endpoints)"
echo "    ${NAME_PREFIX}-private-${AZ_A}  ${PRIVATE_SUBNET_CIDRS[0]}  (${AZ_A})"
echo "    ${NAME_PREFIX}-private-${AZ_B}  ${PRIVATE_SUBNET_CIDRS[1]}  (${AZ_B})"
echo ""
echo "  Other VPC resources: Internet Gateway, public + private route tables"
echo "                       default SG ingress/egress rules removed"
echo ""
echo "  Terraform state  (shared across all ${PROJECT_NAME} environments)"
echo "    S3 bucket      : ${TFSTATE_BUCKET}  (versioned, encrypted, HTTPS-only)"
echo "    DynamoDB table : ${TFSTATE_TABLE}  (state locking, PITR enabled)"
echo "    State key      : ${TFSTATE_KEY}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -r -p "Create these resources? [y/N]: " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi
echo ""

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
log "Creating VPC (${VPC_CIDR})..."
VPC_ID=$(aws ec2 create-vpc \
  --region "${AWS_REGION}" \
  --cidr-block "${VPC_CIDR}" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${NAME_PREFIX}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}}]" \
  --query 'Vpc.VpcId' --output text)
log "VPC: ${VPC_ID}"

aws ec2 modify-vpc-attribute --region "${AWS_REGION}" --vpc-id "${VPC_ID}" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --region "${AWS_REGION}" --vpc-id "${VPC_ID}" --enable-dns-support

# Remove all rules from the default security group so it is inert
DEFAULT_SG_ID=$(aws ec2 describe-security-groups \
  --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=default" \
  --query 'SecurityGroups[0].GroupId' --output text)

DEFAULT_SG_INGRESS=$(aws ec2 describe-security-groups \
  --region "${AWS_REGION}" \
  --group-ids "${DEFAULT_SG_ID}" \
  --query 'SecurityGroups[0].IpPermissions' --output json)

DEFAULT_SG_EGRESS=$(aws ec2 describe-security-groups \
  --region "${AWS_REGION}" \
  --group-ids "${DEFAULT_SG_ID}" \
  --query 'SecurityGroups[0].IpPermissionsEgress' --output json)

if [[ "${DEFAULT_SG_INGRESS}" != "[]" ]]; then
  aws ec2 revoke-security-group-ingress \
    --region "${AWS_REGION}" \
    --group-id "${DEFAULT_SG_ID}" \
    --ip-permissions "${DEFAULT_SG_INGRESS}" > /dev/null
fi

if [[ "${DEFAULT_SG_EGRESS}" != "[]" ]]; then
  aws ec2 revoke-security-group-egress \
    --region "${AWS_REGION}" \
    --group-id "${DEFAULT_SG_ID}" \
    --ip-permissions "${DEFAULT_SG_EGRESS}" > /dev/null
fi
log "Default security group ${DEFAULT_SG_ID} rules removed."

# ---------------------------------------------------------------------------
# VPC Flow Logs
# ---------------------------------------------------------------------------
log "Setting up VPC flow logs..."

FLOW_LOG_GROUP="/${NAME_PREFIX}/vpc-flow-logs"
FLOW_LOGS_ROLE_NAME="${NAME_PREFIX}-vpc-flow-logs"

aws logs create-log-group \
  --log-group-name "${FLOW_LOG_GROUP}" \
  --region "${AWS_REGION}" \
  --tags Project="${PROJECT_NAME}",Environment="${ENVIRONMENT}" 2>/dev/null || true

aws logs put-retention-policy \
  --log-group-name "${FLOW_LOG_GROUP}" \
  --retention-in-days 90 \
  --region "${AWS_REGION}"

if ! aws iam get-role --role-name "${FLOW_LOGS_ROLE_NAME}" 2>/dev/null | grep -q '"RoleId"'; then
  TRUST_POLICY=$(jq -n '{
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Principal: { Service: "vpc-flow-logs.amazonaws.com" },
      Action: "sts:AssumeRole"
    }]
  }')

  aws iam create-role \
    --role-name "${FLOW_LOGS_ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" > /dev/null

  ROLE_POLICY=$(jq -n '{
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Action: [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      Resource: "*"
    }]
  }')

  aws iam put-role-policy \
    --role-name "${FLOW_LOGS_ROLE_NAME}" \
    --policy-name "VpcFlowLogsPolicy" \
    --policy-document "${ROLE_POLICY}"
fi

FLOW_LOGS_ROLE_ARN=$(aws iam get-role \
  --role-name "${FLOW_LOGS_ROLE_NAME}" \
  --query 'Role.Arn' --output text)

aws ec2 create-flow-logs \
  --region "${AWS_REGION}" \
  --resource-type VPC \
  --resource-ids "${VPC_ID}" \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name "${FLOW_LOG_GROUP}" \
  --deliver-logs-permission-arn "${FLOW_LOGS_ROLE_ARN}" > /dev/null
log "Flow logs → ${FLOW_LOG_GROUP} (90-day retention)"

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
log "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "${AWS_REGION}" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${NAME_PREFIX}-igw},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}}]" \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --region "${AWS_REGION}" --vpc-id "${VPC_ID}" --internet-gateway-id "${IGW_ID}"
log "IGW: ${IGW_ID}"

# ---------------------------------------------------------------------------
# Public Subnets
# ---------------------------------------------------------------------------
log "Creating public subnets..."
PUBLIC_SUBNET_A=$(aws ec2 create-subnet \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PUBLIC_SUBNET_CIDRS[0]}" \
  --availability-zone "${AZ_A}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${NAME_PREFIX}-public-${AZ_A}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}},{Key=Type,Value=public}]" \
  --query 'Subnet.SubnetId' --output text)

PUBLIC_SUBNET_B=$(aws ec2 create-subnet \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PUBLIC_SUBNET_CIDRS[1]}" \
  --availability-zone "${AZ_B}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${NAME_PREFIX}-public-${AZ_B}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}},{Key=Type,Value=public}]" \
  --query 'Subnet.SubnetId' --output text)

aws ec2 modify-subnet-attribute --region "${AWS_REGION}" --subnet-id "${PUBLIC_SUBNET_A}" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --region "${AWS_REGION}" --subnet-id "${PUBLIC_SUBNET_B}" --map-public-ip-on-launch
log "Public subnets: ${PUBLIC_SUBNET_A}, ${PUBLIC_SUBNET_B}"

# ---------------------------------------------------------------------------
# Public Route Table
# ---------------------------------------------------------------------------
log "Creating public route table..."
PUBLIC_RTB=$(aws ec2 create-route-table \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${NAME_PREFIX}-public-rtb},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}}]" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --region "${AWS_REGION}" --route-table-id "${PUBLIC_RTB}" --destination-cidr-block 0.0.0.0/0 --gateway-id "${IGW_ID}" > /dev/null
aws ec2 associate-route-table --region "${AWS_REGION}" --route-table-id "${PUBLIC_RTB}" --subnet-id "${PUBLIC_SUBNET_A}" > /dev/null
aws ec2 associate-route-table --region "${AWS_REGION}" --route-table-id "${PUBLIC_RTB}" --subnet-id "${PUBLIC_SUBNET_B}" > /dev/null

# ---------------------------------------------------------------------------
# Private Subnets
# ---------------------------------------------------------------------------
log "Creating private subnets..."
PRIVATE_SUBNET_A=$(aws ec2 create-subnet \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PRIVATE_SUBNET_CIDRS[0]}" \
  --availability-zone "${AZ_A}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${NAME_PREFIX}-private-${AZ_A}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}},{Key=Type,Value=private}]" \
  --query 'Subnet.SubnetId' --output text)

PRIVATE_SUBNET_B=$(aws ec2 create-subnet \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PRIVATE_SUBNET_CIDRS[1]}" \
  --availability-zone "${AZ_B}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${NAME_PREFIX}-private-${AZ_B}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}},{Key=Type,Value=private}]" \
  --query 'Subnet.SubnetId' --output text)
log "Private subnets: ${PRIVATE_SUBNET_A}, ${PRIVATE_SUBNET_B}"

# ---------------------------------------------------------------------------
# Private Route Table
# ---------------------------------------------------------------------------
log "Creating private route table..."
PRIVATE_RTB=$(aws ec2 create-route-table \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${NAME_PREFIX}-private-rtb},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENVIRONMENT}}]" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 associate-route-table --region "${AWS_REGION}" --route-table-id "${PRIVATE_RTB}" --subnet-id "${PRIVATE_SUBNET_A}" > /dev/null
aws ec2 associate-route-table --region "${AWS_REGION}" --route-table-id "${PRIVATE_RTB}" --subnet-id "${PRIVATE_SUBNET_B}" > /dev/null

# ---------------------------------------------------------------------------
# Terraform state: S3 bucket (shared across all environments for this project)
# ---------------------------------------------------------------------------
log "Checking Terraform state S3 bucket (${TFSTATE_BUCKET})..."
if aws s3api head-bucket --bucket "${TFSTATE_BUCKET}" --region "${AWS_REGION}" 2>/dev/null; then
  log "S3 bucket already exists — skipping creation."
else
  log "Creating S3 bucket..."
  if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${TFSTATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --object-ownership BucketOwnerEnforced > /dev/null
  else
    aws s3api create-bucket \
      --bucket "${TFSTATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}" \
      --object-ownership BucketOwnerEnforced > /dev/null
  fi

  aws s3api put-bucket-versioning \
    --bucket "${TFSTATE_BUCKET}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "${TFSTATE_BUCKET}" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

  aws s3api put-public-access-block \
    --bucket "${TFSTATE_BUCKET}" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  # Deny any non-HTTPS access to state files
  BUCKET_POLICY=$(jq -n --arg bucket "${TFSTATE_BUCKET}" '{
    Version: "2012-10-17",
    Statement: [{
      Sid: "DenyNonSSL",
      Effect: "Deny",
      Principal: "*",
      Action: "s3:*",
      Resource: [
        "arn:aws:s3:::\($bucket)",
        "arn:aws:s3:::\($bucket)/*"
      ],
      Condition: { Bool: { "aws:SecureTransport": "false" } }
    }]
  }')
  aws s3api put-bucket-policy --bucket "${TFSTATE_BUCKET}" --policy "${BUCKET_POLICY}"

  # Expire noncurrent state versions after 90 days to bound storage growth
  LIFECYCLE_CONFIG=$(jq -n '{
    Rules: [{
      ID: "expire-noncurrent-state-versions",
      Status: "Enabled",
      Filter: { Prefix: "" },
      NoncurrentVersionExpiration: { NoncurrentDays: 90 },
      AbortIncompleteMultipartUpload: { DaysAfterInitiation: 7 }
    }]
  }')
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "${TFSTATE_BUCKET}" \
    --lifecycle-configuration "${LIFECYCLE_CONFIG}"

  log "S3 bucket created: versioned, AES256, public access blocked, HTTPS-only policy, 90-day version lifecycle."
fi

# ---------------------------------------------------------------------------
# Terraform state: DynamoDB table (shared across all environments for this project)
# ---------------------------------------------------------------------------
log "Checking Terraform state DynamoDB table (${TFSTATE_TABLE})..."
if aws dynamodb describe-table --table-name "${TFSTATE_TABLE}" --region "${AWS_REGION}" 2>/dev/null | grep -q '"TableStatus"'; then
  log "DynamoDB table already exists — skipping creation."
else
  log "Creating DynamoDB table..."
  aws dynamodb create-table \
    --table-name "${TFSTATE_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}" \
    --tags Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=bootstrap > /dev/null

  log "Waiting for DynamoDB table to become active..."
  aws dynamodb wait table-exists \
    --table-name "${TFSTATE_TABLE}" \
    --region "${AWS_REGION}"

  aws dynamodb update-continuous-backups \
    --table-name "${TFSTATE_TABLE}" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "${AWS_REGION}" > /dev/null
  log "DynamoDB table created with PITR enabled."
fi

# ---------------------------------------------------------------------------
# Write outputs
# ---------------------------------------------------------------------------
OUTPUT_FILE="${SCRIPT_DIR}/${ENVIRONMENT:+${ENVIRONMENT}-}vpc-outputs.json"
cat > "${OUTPUT_FILE}" <<EOF
{
  "vpc_id": "${VPC_ID}",
  "public_subnet_ids": ["${PUBLIC_SUBNET_A}", "${PUBLIC_SUBNET_B}"],
  "private_subnet_ids": ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"],
  "db_subnet_ids": ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"],
  "internet_gateway_id": "${IGW_ID}"
}
EOF

TFVARS_FILE="${SCRIPT_DIR}/${ENVIRONMENT:+${ENVIRONMENT}.}tfvars.recommended"

if ${IS_PROD}; then
cat > "${TFVARS_FILE}" <<EOF
aws_region   = "${AWS_REGION}"
project_name = "${PROJECT_NAME}"
environment  = "${ENVIRONMENT}"

vpc_id             = "${VPC_ID}"
public_subnet_ids  = ["${PUBLIC_SUBNET_A}", "${PUBLIC_SUBNET_B}"]
private_subnet_ids = ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"]
db_subnet_ids      = ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"]

container_registry_type = "ecr"
ecr_force_delete        = false
container_image_tag     = "latest"

ecs_launch_type      = "EC2"
ec2_market_type      = "on-demand"
ec2_instance_type    = "t3.small"
ec2_desired_capacity = 2
ec2_min_size         = 2
ec2_max_size         = 6

ecs_service_desired_count = 2
ecs_service_min_capacity  = 2
ecs_service_max_capacity  = 6

db_use_iam_auth                  = true
db_publicly_accessible           = false
db_instance_class                = "db.t4g.small"
db_allocated_storage             = 20
db_max_allocated_storage         = 200
db_backup_retention_period       = 7
db_multi_az                      = true
db_deletion_protection           = true
db_skip_final_snapshot           = false
db_performance_insights_enabled  = true

enable_container_insights        = true
enable_waf                       = true
cloudwatch_log_retention_in_days = 90
allowed_ingress_cidrs            = ["0.0.0.0/0"]

app_environment = {
  APP_NAME = "${PROJECT_NAME}"
  DEBUG    = "false"
}
EOF
else
cat > "${TFVARS_FILE}" <<EOF
aws_region   = "${AWS_REGION}"
project_name = "${PROJECT_NAME}"
environment  = "${ENVIRONMENT}"

vpc_id             = "${VPC_ID}"
public_subnet_ids  = ["${PUBLIC_SUBNET_A}", "${PUBLIC_SUBNET_B}"]
private_subnet_ids = ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"]
db_subnet_ids      = ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"]

container_registry_type = "ecr"
ecr_force_delete        = true
container_image_tag     = "latest"

ecs_launch_type      = "EC2"
ec2_market_type      = "spot"
ec2_instance_type    = "t3.micro"
ec2_desired_capacity = 1
ec2_min_size         = 1
ec2_max_size         = 2

ecs_service_desired_count = 1
ecs_service_min_capacity  = 1
ecs_service_max_capacity  = 3

db_use_iam_auth                  = false
db_publicly_accessible           = false
db_instance_class                = "db.t4g.micro"
db_allocated_storage             = 20
db_max_allocated_storage         = 100
db_backup_retention_period       = 1
db_multi_az                      = false
db_deletion_protection           = false
db_skip_final_snapshot           = true
db_performance_insights_enabled  = false

enable_container_insights        = false
enable_waf                       = false
cloudwatch_log_retention_in_days = 7
allowed_ingress_cidrs            = ["0.0.0.0/0"]

app_environment = {
  APP_NAME = "${PROJECT_NAME}"
  DEBUG    = "true"
}
EOF
fi

BACKEND_FILE="${TERRAFORM_DIR}/backend.tf"
cat > "${BACKEND_FILE}" <<EOF
# Auto-generated by bootstrap-aws/create-vpc.sh — do not commit (see .gitignore)
terraform {
  backend "s3" {
    bucket         = "${TFSTATE_BUCKET}"
    key            = "${TFSTATE_KEY}"
    region         = "${AWS_REGION}"
    dynamodb_table = "${TFSTATE_TABLE}"
    encrypt        = true
  }
}
EOF

log "Done!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Output files written:"
echo "    ${OUTPUT_FILE}"
echo "    ${TFVARS_FILE}"
echo "    ${BACKEND_FILE}"
echo ""
echo "  To deploy:"
echo "    cp ${TFVARS_FILE} terraform/${ENVIRONMENT}.tfvars"
echo "    cd terraform && terraform init && terraform apply -var-file=${ENVIRONMENT}.tfvars"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
