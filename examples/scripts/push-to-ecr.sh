#!/bin/bash

# ===========================================
# ECR에 Docker 이미지 푸시 스크립트
# ===========================================
#
# 사용법:
#   ./push-to-ecr.sh <service-name> <dockerfile-path> <tag>
#
# 예시:
#   ./push-to-ecr.sh gateway-api ./Dockerfile latest
#   ./push-to-ecr.sh reservation-api ../apps/reservation-api v1.0.0
# ===========================================

set -e

SERVICE_NAME=$1
DOCKERFILE_PATH=${2:-./Dockerfile}
TAG=${3:-latest}

if [ -z "$SERVICE_NAME" ]; then
  echo "Error: Service name required"
  echo "Usage: $0 <service-name> <dockerfile-path> <tag>"
  echo "Example: $0 gateway-api ./Dockerfile latest"
  exit 1
fi

# AWS Region 및 Account ID
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECR 리포지토리 이름
REPO_NAME="cat-${SERVICE_NAME}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"

echo "=========================================="
echo "Pushing Docker image to ECR"
echo "=========================================="
echo "Service: $SERVICE_NAME"
echo "Dockerfile: $DOCKERFILE_PATH"
echo "Tag: $TAG"
echo "ECR URI: $ECR_URI"
echo ""

# 1. ECR 로그인
echo "Step 1: Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo ""

# 2. Docker 이미지 빌드
echo "Step 2: Building Docker image..."
DOCKERFILE_DIR=$(dirname $DOCKERFILE_PATH)
docker build -t $REPO_NAME:$TAG -f $DOCKERFILE_PATH $DOCKERFILE_DIR

echo ""

# 3. 이미지 태그
echo "Step 3: Tagging image..."
docker tag $REPO_NAME:$TAG $ECR_URI:$TAG

# latest 태그도 함께 푸시
if [ "$TAG" != "latest" ]; then
  docker tag $REPO_NAME:$TAG $ECR_URI:latest
fi

echo ""

# 4. ECR에 푸시
echo "Step 4: Pushing to ECR..."
docker push $ECR_URI:$TAG

if [ "$TAG" != "latest" ]; then
  docker push $ECR_URI:latest
fi

echo ""
echo "=========================================="
echo "Push completed!"
echo "=========================================="
echo ""
echo "Image URI: $ECR_URI:$TAG"
echo ""
echo "Next steps:"
echo "  1. Update Task Definition with new image"
echo "  2. Deploy ECS Service:"
echo "     ./deploy-ecs-service.sh $SERVICE_NAME 1"
