#!/bin/bash

# Terraform tfvars S3 Sync Script
# Usage: ./sync-tfvars.sh [upload|download]

set -e

S3_BUCKET="softbank2025-cat-tfstate"
S3_KEY="cat-cicd/terraform.tfvars"
S3_PATH="s3://${S3_BUCKET}/${S3_KEY}"
LOCAL_FILE="terraform.tfvars"
REGION="ap-northeast-2"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

function usage() {
    echo "Usage: $0 [upload|download]"
    echo ""
    echo "Commands:"
    echo "  upload     Upload local terraform.tfvars to S3"
    echo "  download   Download terraform.tfvars from S3 to local"
    echo ""
    echo "Example:"
    echo "  $0 download"
    echo "  $0 upload"
    exit 1
}

function check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed${NC}"
        exit 1
    fi
}

function download_tfvars() {
    echo -e "${YELLOW}Downloading terraform.tfvars from S3...${NC}"

    if aws s3 cp "${S3_PATH}" "./${LOCAL_FILE}" --region "${REGION}"; then
        echo -e "${GREEN}✓ Successfully downloaded terraform.tfvars from S3${NC}"
        echo -e "${YELLOW}Location: ${S3_PATH}${NC}"
    else
        echo -e "${RED}✗ Failed to download terraform.tfvars from S3${NC}"
        exit 1
    fi
}

function upload_tfvars() {
    if [ ! -f "${LOCAL_FILE}" ]; then
        echo -e "${RED}Error: ${LOCAL_FILE} not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Uploading terraform.tfvars to S3...${NC}"

    if aws s3 cp "./${LOCAL_FILE}" "${S3_PATH}" --region "${REGION}"; then
        echo -e "${GREEN}✓ Successfully uploaded terraform.tfvars to S3${NC}"
        echo -e "${YELLOW}Location: ${S3_PATH}${NC}"
    else
        echo -e "${RED}✗ Failed to upload terraform.tfvars to S3${NC}"
        exit 1
    fi
}

# Main
check_aws_cli

case "${1:-}" in
    upload)
        upload_tfvars
        ;;
    download)
        download_tfvars
        ;;
    *)
        usage
        ;;
esac
