#!/usr/bin/env bash
set -euo pipefail

# Tears down the VPC and networking resources created by create-vpc.sh.
# Run `terraform destroy` before this script — subnets with active ENIs cannot be deleted.

SCRIPT_DIR="$(dirname "$0")"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] WARNING: $*"; }

skip_if_empty() {
  # Usage: skip_if_empty "$value" && <command>
  [[ -n "$1" && "$1" != "None" && "$1" != "null" ]]
}

# ---------------------------------------------------------------------------
# Prompts — must match the values used in create-vpc.sh
# ---------------------------------------------------------------------------
read -r -p "AWS region [us-west-2]: " AWS_REGION
AWS_REGION="${AWS_REGION:-us-west-2}"

read -r -p "Project name: " PROJECT_NAME
read -r -p "Environment name: " ENVIRONMENT

NAME_PREFIX="${PROJECT_NAME}${ENVIRONMENT:+-${ENVIRONMENT}}"

log "Checking AWS credentials..."
if ! CALLER=$(aws sts get-caller-identity --region "${AWS_REGION}" --output json 2>&1); then
  echo "Error: AWS credentials are not configured or are invalid."
  echo "  Details: ${CALLER}"
  exit 1
fi
AWS_ACCOUNT=$(echo "${CALLER}" | jq -r '.Account')
AWS_ARN=$(echo "${CALLER}" | jq -r '.Arn')

TFSTATE_BUCKET="${PROJECT_NAME}-tfstate-${AWS_ACCOUNT}"
TFSTATE_TABLE="${PROJECT_NAME}-tfstate-lock"

# ---------------------------------------------------------------------------
# Look up resources by Name tag
# ---------------------------------------------------------------------------
log "Looking up resources tagged for ${NAME_PREFIX}..."

VPC_ID=$(aws ec2 describe-vpcs \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Name,Values=${NAME_PREFIX}" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)

if [[ -z "${VPC_ID}" || "${VPC_ID}" == "None" ]]; then
  echo "  No VPC found with Name=${NAME_PREFIX} in ${AWS_REGION}."
  echo "  Nothing to destroy."
  exit 0
fi

IGW_ID=$(aws ec2 describe-internet-gateways \
  --region "${AWS_REGION}" \
  --filters "Name=tag:Name,Values=${NAME_PREFIX}-igw" \
  --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || true)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[].SubnetId' --output text 2>/dev/null || true)

ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
  --region "${AWS_REGION}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${NAME_PREFIX}-*-rtb" \
  --query 'RouteTables[].RouteTableId' --output text 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Preview & confirmation
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Resources to be destroyed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  AWS account : ${AWS_ACCOUNT}"
echo "  Identity    : ${AWS_ARN}"
echo "  Region      : ${AWS_REGION}"
echo "  Project     : ${PROJECT_NAME}"
echo "  Environment : ${ENVIRONMENT}"
echo ""
echo "  VPC              : ${VPC_ID}"
echo "  Internet Gateway : ${IGW_ID:-not found}"
echo "  Route tables     : ${ROUTE_TABLE_IDS:-none found}"
echo "  Subnets          : ${SUBNET_IDS:-none found}"
echo ""
echo "  NOTE: Run 'terraform destroy' first — subnets with active ENIs"
echo "        cannot be deleted."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -r -p "Destroy these VPC resources? [y/N]: " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi
echo ""

# ---------------------------------------------------------------------------
# Route table associations & route tables
# ---------------------------------------------------------------------------
for RTB_ID in ${ROUTE_TABLE_IDS}; do
  log "Disassociating route table ${RTB_ID}..."
  ASSOC_IDS=$(aws ec2 describe-route-tables \
    --region "${AWS_REGION}" \
    --route-table-ids "${RTB_ID}" \
    --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
    --output text 2>/dev/null || true)
  for ASSOC_ID in ${ASSOC_IDS}; do
    aws ec2 disassociate-route-table --region "${AWS_REGION}" --association-id "${ASSOC_ID}"
  done

  log "Deleting route table ${RTB_ID}..."
  aws ec2 delete-route-table --region "${AWS_REGION}" --route-table-id "${RTB_ID}"
done

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------
for SUBNET_ID in ${SUBNET_IDS}; do
  log "Deleting subnet ${SUBNET_ID}..."
  aws ec2 delete-subnet --region "${AWS_REGION}" --subnet-id "${SUBNET_ID}"
done

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
if skip_if_empty "${IGW_ID}"; then
  log "Detaching Internet Gateway ${IGW_ID}..."
  aws ec2 detach-internet-gateway \
    --region "${AWS_REGION}" \
    --internet-gateway-id "${IGW_ID}" \
    --vpc-id "${VPC_ID}"

  log "Deleting Internet Gateway ${IGW_ID}..."
  aws ec2 delete-internet-gateway --region "${AWS_REGION}" --internet-gateway-id "${IGW_ID}"
fi

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
log "Deleting VPC ${VPC_ID}..."
aws ec2 delete-vpc --region "${AWS_REGION}" --vpc-id "${VPC_ID}"
log "VPC deleted."

# ---------------------------------------------------------------------------
# Clean up local output files for this environment
# ---------------------------------------------------------------------------
OUTPUT_FILE="${SCRIPT_DIR}/${ENVIRONMENT:+${ENVIRONMENT}-}vpc-outputs.json"
TFVARS_FILE="${SCRIPT_DIR}/${ENVIRONMENT:+${ENVIRONMENT}.}tfvars.recommended"

[[ -f "${OUTPUT_FILE}" ]] && rm "${OUTPUT_FILE}" && log "Removed ${OUTPUT_FILE}"
[[ -f "${TFVARS_FILE}" ]] && rm "${TFVARS_FILE}" && log "Removed ${TFVARS_FILE}"

# ---------------------------------------------------------------------------
# Optional: delete shared Terraform state infrastructure
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Shared Terraform state infrastructure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  S3 bucket      : ${TFSTATE_BUCKET}"
echo "  DynamoDB table : ${TFSTATE_TABLE}"
echo ""
echo "  WARNING: These resources are shared across ALL ${PROJECT_NAME} environments."
echo "           Only delete them if this is the last environment for this project."
echo ""
read -r -p "Also delete the shared Terraform state infrastructure? [y/N]: " DELETE_STATE
if [[ ! "${DELETE_STATE}" =~ ^[Yy]$ ]]; then
  echo "  Skipping — state infrastructure preserved."
else
  # S3 bucket: delete all object versions and delete markers first (versioning enabled)
  if aws s3api head-bucket --bucket "${TFSTATE_BUCKET}" --region "${AWS_REGION}" 2>/dev/null; then
    log "Emptying versioned S3 bucket ${TFSTATE_BUCKET}..."

    VERSIONS=$(aws s3api list-object-versions \
      --bucket "${TFSTATE_BUCKET}" \
      --query 'Versions[].{Key:Key,VersionId:VersionId}' \
      --output json 2>/dev/null)
    if [[ "${VERSIONS}" != "null" && "${VERSIONS}" != "[]" && -n "${VERSIONS}" ]]; then
      echo "${VERSIONS}" | jq -c '.[]' | while read -r obj; do
        KEY=$(echo "${obj}" | jq -r '.Key')
        VID=$(echo "${obj}" | jq -r '.VersionId')
        aws s3api delete-object --bucket "${TFSTATE_BUCKET}" --key "${KEY}" --version-id "${VID}" > /dev/null
      done
    fi

    MARKERS=$(aws s3api list-object-versions \
      --bucket "${TFSTATE_BUCKET}" \
      --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
      --output json 2>/dev/null)
    if [[ "${MARKERS}" != "null" && "${MARKERS}" != "[]" && -n "${MARKERS}" ]]; then
      echo "${MARKERS}" | jq -c '.[]' | while read -r obj; do
        KEY=$(echo "${obj}" | jq -r '.Key')
        VID=$(echo "${obj}" | jq -r '.VersionId')
        aws s3api delete-object --bucket "${TFSTATE_BUCKET}" --key "${KEY}" --version-id "${VID}" > /dev/null
      done
    fi

    log "Deleting S3 bucket ${TFSTATE_BUCKET}..."
    aws s3api delete-bucket --bucket "${TFSTATE_BUCKET}" --region "${AWS_REGION}"
    log "S3 bucket deleted."
  else
    log "S3 bucket ${TFSTATE_BUCKET} not found — skipping."
  fi

  # DynamoDB table
  if aws dynamodb describe-table --table-name "${TFSTATE_TABLE}" --region "${AWS_REGION}" 2>/dev/null | grep -q '"TableStatus"'; then
    log "Deleting DynamoDB table ${TFSTATE_TABLE}..."
    aws dynamodb delete-table --table-name "${TFSTATE_TABLE}" --region "${AWS_REGION}" > /dev/null
    log "DynamoDB table deleted."
  else
    log "DynamoDB table ${TFSTATE_TABLE} not found — skipping."
  fi
fi

log "Done!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Teardown complete for ${NAME_PREFIX}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
