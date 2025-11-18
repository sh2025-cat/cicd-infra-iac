#!/bin/bash

# Local GitHub Actions Workflow Test Script
# This script simulates the Terraform workflow that runs in GitHub Actions

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
S3_BUCKET="softbank2025-cat-tfstate"
S3_KEY="cat-cicd/terraform.tfvars"
REGION="ap-northeast-2"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Local Terraform Workflow Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check required tools
echo -e "${YELLOW}[1/6] Checking required tools...${NC}"
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform is not installed${NC}"
    exit 1
fi
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ All required tools are installed${NC}"
echo ""

# Step 2: Terraform Format Check
echo -e "${YELLOW}[2/6] Running Terraform Format Check...${NC}"
if terraform fmt -check -recursive; then
    echo -e "${GREEN}✓ Terraform format check passed${NC}"
else
    echo -e "${RED}✗ Terraform format check failed${NC}"
    echo -e "${YELLOW}Run 'terraform fmt -recursive' to fix formatting${NC}"
    exit 1
fi
echo ""

# Step 3: Download terraform.tfvars from S3
echo -e "${YELLOW}[3/6] Downloading terraform.tfvars from S3...${NC}"
if aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" ./terraform.tfvars --region "${REGION}" 2>/dev/null; then
    echo -e "${GREEN}✓ Successfully downloaded terraform.tfvars${NC}"
else
    echo -e "${YELLOW}⚠ Could not download terraform.tfvars from S3${NC}"
    echo -e "${YELLOW}  Using local terraform.tfvars if exists${NC}"
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${RED}✗ No terraform.tfvars found${NC}"
        exit 1
    fi
fi
echo ""

# Step 4: Terraform Init
echo -e "${YELLOW}[4/6] Running Terraform Init...${NC}"
if terraform init -input=false; then
    echo -e "${GREEN}✓ Terraform init successful${NC}"
else
    echo -e "${RED}✗ Terraform init failed${NC}"
    exit 1
fi
echo ""

# Step 5: Terraform Validate
echo -e "${YELLOW}[5/6] Running Terraform Validate...${NC}"
if terraform validate; then
    echo -e "${GREEN}✓ Terraform validation passed${NC}"
else
    echo -e "${RED}✗ Terraform validation failed${NC}"
    exit 1
fi
echo ""

# Step 6: Terraform Plan
echo -e "${YELLOW}[6/6] Running Terraform Plan...${NC}"
if terraform plan -input=false -no-color -out=tfplan.test; then
    echo -e "${GREEN}✓ Terraform plan completed successfully${NC}"

    # Show plan summary
    echo ""
    echo -e "${BLUE}Plan Summary:${NC}"
    terraform show -no-color tfplan.test | head -50
    echo ""
    echo -e "${YELLOW}Full plan saved to: tfplan.test${NC}"
    echo -e "${YELLOW}To view full plan: terraform show tfplan.test${NC}"
else
    echo -e "${RED}✗ Terraform plan failed${NC}"
    exit 1
fi
echo ""

# Success
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ All workflow tests passed!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  - Review the plan: ${BLUE}terraform show tfplan.test${NC}"
echo -e "  - Apply changes: ${BLUE}terraform apply tfplan.test${NC}"
echo -e "  - Clean up: ${BLUE}rm -f tfplan.test${NC}"
echo ""
