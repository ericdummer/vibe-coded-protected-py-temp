#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDRS=("10.0.1.0/24" "10.0.2.0/24")
PRIVATE_SUBNET_CIDRS=("10.0.101.0/24" "10.0.102.0/24")
# ---------------------------------------------------------------------------

OUTPUT_FILE="$(dirname "$0")/vpc-outputs.json"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
read -r -p "AWS region [us-west-2]: " AWS_REGION
AWS_REGION="${AWS_REGION:-us-west-2}"

while true; do
  read -r -p "Project name: " PROJECT_NAME
  if [[ -z "${PROJECT_NAME}" ]]; then
    echo "  Error: project name cannot be empty."
  elif [[ ! "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    echo "  Error: project name must be lowercase letters, numbers, and hyphens only,"
    echo "         must start and end with a letter or number (e.g. my-project)."
  elif [[ ${#PROJECT_NAME} -gt 32 ]]; then
    echo "  Error: project name must be 32 characters or fewer (${#PROJECT_NAME} given)."
  else
    break
  fi
done

log "Checking AWS credentials..."
if ! CALLER=$(aws sts get-caller-identity --region "${AWS_REGION}" --output json 2>&1); then
  echo "Error: AWS credentials are not configured or are invalid."
  echo "  Run 'aws configure' or set AWS_PROFILE to fix this."
  echo "  Details: ${CALLER}"
  exit 1
fi
AWS_ACCOUNT=$(echo "${CALLER}" | jq -r '.Account')
AWS_ARN=$(echo "${CALLER}" | jq -r '.Arn')

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
echo ""
echo "  VPC"
echo "    CIDR      : ${VPC_CIDR}"
echo ""
echo "  Public subnets (attached to Internet Gateway)"
echo "    ${PROJECT_NAME}-public-${AZ_A}   ${PUBLIC_SUBNET_CIDRS[0]}   (${AZ_A})"
echo "    ${PROJECT_NAME}-public-${AZ_B}   ${PUBLIC_SUBNET_CIDRS[1]}   (${AZ_B})"
echo ""
echo "  Private subnets (no NAT Gateway — AWS service access via VPC endpoints)"
echo "    ${PROJECT_NAME}-private-${AZ_A}  ${PRIVATE_SUBNET_CIDRS[0]}  (${AZ_A})"
echo "    ${PROJECT_NAME}-private-${AZ_B}  ${PRIVATE_SUBNET_CIDRS[1]}  (${AZ_B})"
echo ""
echo "  Other resources: Internet Gateway, public + private route tables"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -r -p "Create these resources? [y/N]: " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi
echo ""

# echo "just testing"; exit 0

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
log "Creating VPC (${VPC_CIDR})..."
VPC_ID=$(aws ec2 create-vpc \
  --region "${AWS_REGION}" \
  --cidr-block "${VPC_CIDR}" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}},{Key=Project,Value=${PROJECT_NAME}}]" \
  --query 'Vpc.VpcId' --output text)
log "VPC: ${VPC_ID}"

aws ec2 modify-vpc-attribute --region "${AWS_REGION}" --vpc-id "${VPC_ID}" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --region "${AWS_REGION}" --vpc-id "${VPC_ID}" --enable-dns-support

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
log "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region "${AWS_REGION}" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw},{Key=Project,Value=${PROJECT_NAME}}]" \
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
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-${AZ_A}},{Key=Project,Value=${PROJECT_NAME}},{Key=Type,Value=public}]" \
  --query 'Subnet.SubnetId' --output text)

PUBLIC_SUBNET_B=$(aws ec2 create-subnet \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PUBLIC_SUBNET_CIDRS[1]}" \
  --availability-zone "${AZ_B}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-${AZ_B}},{Key=Project,Value=${PROJECT_NAME}},{Key=Type,Value=public}]" \
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
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-rtb},{Key=Project,Value=${PROJECT_NAME}}]" \
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
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-${AZ_A}},{Key=Project,Value=${PROJECT_NAME}},{Key=Type,Value=private}]" \
  --query 'Subnet.SubnetId' --output text)

PRIVATE_SUBNET_B=$(aws ec2 create-subnet \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --cidr-block "${PRIVATE_SUBNET_CIDRS[1]}" \
  --availability-zone "${AZ_B}" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-${AZ_B}},{Key=Project,Value=${PROJECT_NAME}},{Key=Type,Value=private}]" \
  --query 'Subnet.SubnetId' --output text)
log "Private subnets: ${PRIVATE_SUBNET_A}, ${PRIVATE_SUBNET_B}"

# ---------------------------------------------------------------------------
# Private Route Table
# ---------------------------------------------------------------------------
log "Creating private route table..."
PRIVATE_RTB=$(aws ec2 create-route-table \
  --region "${AWS_REGION}" \
  --vpc-id "${VPC_ID}" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-rtb},{Key=Project,Value=${PROJECT_NAME}}]" \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 associate-route-table --region "${AWS_REGION}" --route-table-id "${PRIVATE_RTB}" --subnet-id "${PRIVATE_SUBNET_A}" > /dev/null
aws ec2 associate-route-table --region "${AWS_REGION}" --route-table-id "${PRIVATE_RTB}" --subnet-id "${PRIVATE_SUBNET_B}" > /dev/null

# ---------------------------------------------------------------------------
# Write outputs
# ---------------------------------------------------------------------------
cat > "${OUTPUT_FILE}" <<EOF
{
  "vpc_id": "${VPC_ID}",
  "public_subnet_ids": ["${PUBLIC_SUBNET_A}", "${PUBLIC_SUBNET_B}"],
  "private_subnet_ids": ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"],
  "db_subnet_ids": ["${PRIVATE_SUBNET_A}", "${PRIVATE_SUBNET_B}"],
  "internet_gateway_id": "${IGW_ID}"
}
EOF

TFVARS_FILE="$(dirname "$0")/dev.tfvars.recommended"
cat > "${TFVARS_FILE}" <<EOF
aws_region   = "${AWS_REGION}"
project_name = "${PROJECT_NAME}"
environment  = "dev"

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
egress_cidrs                     = ["0.0.0.0/0"]

app_environment = {
  APP_NAME = "${PROJECT_NAME}"
  DEBUG    = "true"
}
EOF

log "Done!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Output files written:"
echo "    ${OUTPUT_FILE}"
echo "    ${TFVARS_FILE}"
echo ""
echo "  To deploy:"
echo "    cp ${TFVARS_FILE} terraform/dev.tfvars"
echo "    cd terraform && terraform init && terraform apply -var-file=dev.tfvars"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
