#!/bin/bash

# ===========================================
# ECS Service 배포 스크립트
# ===========================================
#
# 사용법:
#   ./deploy-ecs-service.sh <service-name> <desired-count>
#
# 예시:
#   ./deploy-ecs-service.sh gateway-api 2
#   ./deploy-ecs-service.sh reservation-worker 1
# ===========================================

set -e

SERVICE_NAME=$1
DESIRED_COUNT=${2:-1}

if [ -z "$SERVICE_NAME" ]; then
  echo "Error: Service name required"
  echo "Usage: $0 <service-name> <desired-count>"
  echo "Example: $0 gateway-api 2"
  exit 1
fi

# Terraform outputs에서 값 가져오기
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "cat-cluster")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
PRIVATE_SUBNETS=$(terraform output -json private_app_subnet_ids 2>/dev/null || echo "[]")
ECS_SG=$(terraform output -raw ecs_tasks_security_group_id 2>/dev/null || echo "")
TARGET_GROUP_ARN=$(terraform output -raw alb_target_group_arn 2>/dev/null || echo "")

# 서브넷을 comma-separated 형식으로 변환
SUBNETS=$(echo $PRIVATE_SUBNETS | jq -r 'join(",")')

echo "=========================================="
echo "Deploying ECS Service: $SERVICE_NAME"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Desired Count: $DESIRED_COUNT"
echo "Subnets: $SUBNETS"
echo "Security Group: $ECS_SG"
echo ""

# 1. Task Definition 등록
echo "Step 1: Registering Task Definition..."
TASK_DEF_FILE="../ecs-task-definitions/${SERVICE_NAME}.json"

if [ ! -f "$TASK_DEF_FILE" ]; then
  echo "Error: Task definition file not found: $TASK_DEF_FILE"
  exit 1
fi

TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://$TASK_DEF_FILE \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Task Definition registered: $TASK_DEF_ARN"
echo ""

# 2. ECS Service 생성 또는 업데이트
echo "Step 2: Creating/Updating ECS Service..."

# Service가 이미 존재하는지 확인
SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services "cat-${SERVICE_NAME}" \
  --query 'services[0].status' \
  --output text 2>/dev/null || echo "MISSING")

if [ "$SERVICE_EXISTS" == "ACTIVE" ]; then
  echo "Service exists. Updating..."
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service "cat-${SERVICE_NAME}" \
    --task-definition $TASK_DEF_ARN \
    --desired-count $DESIRED_COUNT \
    --force-new-deployment
else
  echo "Service does not exist. Creating..."

  # Worker인지 API인지 판단 (worker는 ALB 없음)
  if [[ "$SERVICE_NAME" == *"worker"* ]]; then
    # Worker: Load Balancer 없음
    aws ecs create-service \
      --cluster $CLUSTER_NAME \
      --service-name "cat-${SERVICE_NAME}" \
      --task-definition $TASK_DEF_ARN \
      --desired-count $DESIRED_COUNT \
      --launch-type FARGATE \
      --platform-version LATEST \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
      --tags key=Environment,value=dev key=Project,value=Softbank2025-Cat
  else
    # API: ALB 연결
    CONTAINER_NAME=$(echo $SERVICE_NAME | sed 's/-api//')
    aws ecs create-service \
      --cluster $CLUSTER_NAME \
      --service-name "cat-${SERVICE_NAME}" \
      --task-definition $TASK_DEF_ARN \
      --desired-count $DESIRED_COUNT \
      --launch-type FARGATE \
      --platform-version LATEST \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
      --load-balancers targetGroupArn=$TARGET_GROUP_ARN,containerName=$CONTAINER_NAME-api,containerPort=80 \
      --health-check-grace-period-seconds 60 \
      --tags key=Environment,value=dev key=Project,value=Softbank2025-Cat
  fi
fi

echo ""
echo "=========================================="
echo "Deployment completed!"
echo "=========================================="
echo ""
echo "Check service status:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services cat-${SERVICE_NAME}"
echo ""
echo "Check task logs:"
echo "  aws logs tail /ecs/cat-${SERVICE_NAME} --follow"
