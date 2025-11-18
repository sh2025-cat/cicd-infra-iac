# ECS 애플리케이션 배포 가이드

이 가이드는 애플리케이션 레포지토리에서 ECS로 배포하는 방법을 설명합니다.

## 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [사전 준비사항](#사전-준비사항)
- [1단계: Task Definition 작성](#1단계-task-definition-작성)
- [2단계: ECS Service 생성](#2단계-ecs-service-생성)
- [3단계: GitHub Actions 설정](#3단계-github-actions-설정)
- [배포 프로세스](#배포-프로세스)
- [롤백 방법](#롤백-방법)
- [트러블슈팅](#트러블슈팅)

## 개요

**왜 애플리케이션 레포에서 배포하나요?**

인프라 레포(cat-cicd-infra)는 순수하게 인프라 리소스만 관리하고, 애플리케이션 배포는 각 애플리케이션 레포에서 독립적으로 관리합니다.

**장점:**
- 애플리케이션 팀이 독립적으로 배포 가능
- 인프라 변경 없이 애플리케이션만 업데이트
- 이미지 버전 관리 단순화
- CI/CD 파이프라인 분리

**역할 분담:**
- **인프라 레포** (`cat-cicd-infra`): VPC, ALB, ECS Cluster, ECR, RDS, Target Groups
- **애플리케이션 레포** (`backend`, `frontend`): Docker 이미지, Task Definition, ECS Service

## 아키텍처

```
[Application Repo]
    ↓ GitHub Actions
    ↓ Build Docker Image
    ↓ Push to ECR
    ↓ Register Task Definition
    ↓ Update ECS Service
    ↓
[ECS Service] → [Target Group] → [ALB] → [Users]
```

**ALB 연결 구조:**
```
사용자 요청
  ↓
Cloudflare DNS (*.go-to-learn.net)
  ↓
ALB Listener (HTTP:80 / HTTPS:443)
  ↓
Host Header 확인
  ├─ cicd-api.go-to-learn.net → Backend Target Group → Backend ECS Tasks
  └─ cicd.go-to-learn.net     → Frontend Target Group → Frontend ECS Tasks
```

## 사전 준비사항

인프라 레포에서 배포된 리소스:

```bash
# Terraform outputs 확인
cd cat-cicd-infra
terraform output

# 필요한 값들:
# - ecs_cluster_name: cat-cluster
# - backend_target_group_arn: arn:aws:elasticloadbalancing:...
# - frontend_target_group_arn: arn:aws:elasticloadbalancing:...
# - ecr_repositories.backend.url: 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend
# - ecs_task_execution_role_arn: arn:aws:iam::277679348386:role/cat-cluster-task-execution-role
# - ecs_task_role_arn: arn:aws:iam::277679348386:role/cat-cluster-task-role
# - private_app_subnet_ids: ["subnet-xxx", "subnet-yyy"]
# - ecs_tasks_security_group_id: sg-xxx
```

## 1단계: Task Definition 작성

애플리케이션 레포에 Task Definition 파일을 생성합니다.

### Backend Task Definition

`task-definition.json`:
```json
{
  "family": "cat-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::277679348386:role/cat-cluster-task-execution-role",
  "taskRoleArn": "arn:aws:iam::277679348386:role/cat-cluster-task-role",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ENV",
          "value": "production"
        },
        {
          "name": "DB_HOST",
          "value": "cat-mysql.c7c64cakmi8h.ap-northeast-2.rds.amazonaws.com"
        },
        {
          "name": "DB_PORT",
          "value": "3306"
        },
        {
          "name": "DB_NAME",
          "value": "catdb"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:277679348386:secret:cat/db/password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/cat-backend",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

**주요 필드:**
- `family`: Task Definition 이름 (버전 관리 단위)
- `image`: ECR 이미지 URL + 태그
- `containerPort`: 컨테이너가 리스닝하는 포트 (ALB와 매칭 필요)
- `environment`: 일반 환경 변수
- `secrets`: AWS Secrets Manager에서 가져올 민감 정보
- `healthCheck`: 컨테이너 헬스체크 (ALB 헬스체크와 별개)

## 2단계: ECS Service 생성

### 초기 Service 생성 (AWS CLI)

**Backend Service:**
```bash
aws ecs create-service \
  --cluster cat-cluster \
  --service-name cat-backend-service \
  --task-definition cat-backend \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-01b45f063485ebd3a,subnet-08aa87aebe215f4dd],
    securityGroups=[sg-02e56b242615df825],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:277679348386:targetgroup/cat-backend-tg/aa8318b0be68daa9,containerName=backend,containerPort=8080" \
  --health-check-grace-period-seconds 60 \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
  --enable-execute-command
```

**Frontend Service:**
```bash
aws ecs create-service \
  --cluster cat-cluster \
  --service-name cat-frontend-service \
  --task-definition cat-frontend \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-01b45f063485ebd3a,subnet-08aa87aebe215f4dd],
    securityGroups=[sg-02e56b242615df825],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:277679348386:targetgroup/cat-frontend-tg/3216584938bcfaa8,containerName=frontend,containerPort=3000" \
  --health-check-grace-period-seconds 60 \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
  --enable-execute-command
```

**주요 파라미터:**
- `--desired-count`: 실행할 태스크 개수
- `--network-configuration`: VPC, 서브넷, 보안 그룹 설정
  - `subnets`: Private App 서브넷 (NAT Gateway 통해 외부 통신)
  - `securityGroups`: ECS Tasks용 보안 그룹
  - `assignPublicIp=DISABLED`: Private 서브넷 사용
- `--load-balancers`: ALB Target Group 연결
  - `targetGroupArn`: 인프라 레포에서 생성한 Target Group
  - `containerName`: Task Definition의 컨테이너 이름과 일치
  - `containerPort`: Task Definition의 포트와 일치
- `--health-check-grace-period-seconds`: 초기 헬스체크 대기 시간
- `--deployment-configuration`: 배포 전략
  - `maximumPercent=200`: 배포 중 최대 200% 태스크 실행 가능 (Blue/Green)
  - `minimumHealthyPercent=100`: 최소 100% 정상 태스크 유지
- `--enable-execute-command`: ECS Exec 활성화 (디버깅용)

### ALB 연결 확인

Service 생성 후 ALB Target Group에 자동으로 등록됩니다:

```bash
# Target 등록 확인
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-2:277679348386:targetgroup/cat-backend-tg/aa8318b0be68daa9

# 출력 예시:
# {
#   "TargetHealthDescriptions": [
#     {
#       "Target": {
#         "Id": "10.180.4.123",
#         "Port": 8080
#       },
#       "HealthCheckPort": "8080",
#       "TargetHealth": {
#         "State": "healthy"
#       }
#     }
#   ]
# }
```

**헬스체크 상태:**
- `initial`: 초기 등록 중
- `healthy`: 정상
- `unhealthy`: 비정상 (컨테이너 응답 없음, 헬스체크 실패)
- `draining`: 등록 해제 중

## 3단계: GitHub Actions 설정

### GitHub Secrets 설정

Repository Settings > Secrets and variables > Actions:

| Secret 이름 | 설명 | 예시 값 |
|------------|------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | `wJalrXUtnFEMI/K7MDENG/...` |
| `AWS_REGION` | AWS 리전 | `ap-northeast-2` |
| `ECR_REPOSITORY` | ECR 리포지토리 이름 | `cat-backend` |
| `ECS_CLUSTER` | ECS 클러스터 이름 | `cat-cluster` |
| `ECS_SERVICE` | ECS 서비스 이름 | `cat-backend-service` |
| `CONTAINER_NAME` | 컨테이너 이름 | `backend` |

### GitHub Actions Workflow

`.github/workflows/deploy.yml`:
```yaml
name: Deploy to ECS

on:
  push:
    branches:
      - main

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: cat-backend
  ECS_CLUSTER: cat-cluster
  ECS_SERVICE: cat-backend-service
  CONTAINER_NAME: backend

jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Build, tag, and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
        echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

    - name: Fill in the new image ID in the Amazon ECS task definition
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: task-definition.json
        container-name: ${{ env.CONTAINER_NAME }}
        image: ${{ steps.build-image.outputs.image }}

    - name: Deploy Amazon ECS task definition
      uses: aws-actions/amazon-ecs-deploy-task-definition@v2
      with:
        task-definition: ${{ steps.task-def.outputs.task-definition }}
        service: ${{ env.ECS_SERVICE }}
        cluster: ${{ env.ECS_CLUSTER }}
        wait-for-service-stability: true

    - name: Deployment Summary
      run: |
        echo "## Deployment Successful! 🚀" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "- **Cluster**: ${{ env.ECS_CLUSTER }}" >> $GITHUB_STEP_SUMMARY
        echo "- **Service**: ${{ env.ECS_SERVICE }}" >> $GITHUB_STEP_SUMMARY
        echo "- **Image**: ${{ steps.build-image.outputs.image }}" >> $GITHUB_STEP_SUMMARY
        echo "- **Domain**: https://cicd-api.go-to-learn.net" >> $GITHUB_STEP_SUMMARY
```

**워크플로우 동작:**
1. **Checkout**: 코드 체크아웃
2. **AWS 인증**: AWS credentials 설정
3. **ECR 로그인**: Docker가 ECR에 푸시할 수 있도록 인증
4. **이미지 빌드**: Dockerfile로 이미지 빌드
5. **이미지 태그**: Git SHA와 latest 태그 추가
6. **ECR 푸시**: 이미지를 ECR에 업로드
7. **Task Definition 업데이트**: 새 이미지로 Task Definition 생성
8. **ECS 배포**: 새 Task Definition으로 Service 업데이트
9. **안정화 대기**: 모든 태스크가 정상 상태가 될 때까지 대기

## 배포 프로세스

### 자동 배포 (GitHub Actions)

```bash
# main 브랜치에 푸시하면 자동 배포
git add .
git commit -m "feat: Add new feature"
git push origin main
```

GitHub Actions에서 자동으로:
1. Docker 이미지 빌드
2. ECR에 푸시
3. Task Definition 등록
4. ECS Service 업데이트
5. 헬스체크 확인 후 배포 완료

### 수동 배포 (AWS CLI)

```bash
# 1. ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  277679348386.dkr.ecr.ap-northeast-2.amazonaws.com

# 2. 이미지 빌드 및 푸시
docker build -t cat-backend .
docker tag cat-backend:latest \
  277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:v1.0.0
docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:v1.0.0

# 3. Task Definition 등록
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json

# 4. Service 업데이트 (새 이미지로 배포)
aws ecs update-service \
  --cluster cat-cluster \
  --service cat-backend-service \
  --task-definition cat-backend \
  --force-new-deployment

# 5. 배포 상태 확인
aws ecs describe-services \
  --cluster cat-cluster \
  --services cat-backend-service \
  --query 'services[0].deployments'
```

### 배포 상태 확인

```bash
# ECS 서비스 상태
aws ecs describe-services \
  --cluster cat-cluster \
  --services cat-backend-service

# 실행 중인 태스크 목록
aws ecs list-tasks \
  --cluster cat-cluster \
  --service-name cat-backend-service

# 태스크 상세 정보
aws ecs describe-tasks \
  --cluster cat-cluster \
  --tasks <task-arn>

# 로그 확인 (CloudWatch Logs)
aws logs tail /ecs/cat-backend --follow
```

## 롤백 방법

### 방법 1: 이전 Task Definition으로 롤백

```bash
# Task Definition 목록 확인
aws ecs list-task-definitions --family-prefix cat-backend

# 출력:
# cat-backend:1
# cat-backend:2
# cat-backend:3 (현재)

# 이전 버전(v2)으로 롤백
aws ecs update-service \
  --cluster cat-cluster \
  --service cat-backend-service \
  --task-definition cat-backend:2 \
  --force-new-deployment
```

### 방법 2: 이전 이미지 태그로 재배포

```bash
# ECR 이미지 태그 목록 확인
aws ecr describe-images \
  --repository-name cat-backend \
  --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
  --output table

# task-definition.json에서 이미지 태그 변경
# "image": "277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:v1.0.0"

# 재배포
aws ecs register-task-definition --cli-input-json file://task-definition.json
aws ecs update-service \
  --cluster cat-cluster \
  --service cat-backend-service \
  --task-definition cat-backend \
  --force-new-deployment
```

### 방법 3: GitHub Actions에서 이전 커밋 재배포

```bash
# 이전 커밋으로 체크아웃
git checkout <previous-commit-sha>

# main에 강제 푸시 (주의: 팀과 협의 필요)
git push origin HEAD:main --force

# 또는 revert 커밋 생성
git revert <bad-commit-sha>
git push origin main
```

## 트러블슈팅

### 1. 태스크가 시작되지 않음

**증상:**
```bash
aws ecs describe-services --cluster cat-cluster --services cat-backend-service
# desiredCount: 2, runningCount: 0
```

**원인 및 해결:**

**A. 이미지 Pull 실패**
```bash
# 로그 확인
aws ecs describe-tasks --cluster cat-cluster --tasks <task-arn>

# 에러: "CannotPullContainerError"
# 해결: ECR 권한 확인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com

# Task Execution Role에 ECR 권한 있는지 확인
aws iam get-role-policy --role-name cat-cluster-task-execution-role --policy-name cat-cluster-ecr-policy
```

**B. 서브넷에 인터넷 연결 없음**
```bash
# 에러: "CannotPullContainerError: failed to resolve"
# 해결: Private 서브넷이 NAT Gateway를 통해 인터넷 연결되는지 확인
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-01b45f063485ebd3a"
```

**C. CPU/메모리 부족**
```bash
# Task Definition에서 리소스 증가
# cpu: "256" → "512"
# memory: "512" → "1024"
```

### 2. 헬스체크 실패

**증상:**
```bash
aws elbv2 describe-target-health --target-group-arn <arn>
# State: unhealthy
```

**원인 및 해결:**

**A. 컨테이너 포트 불일치**
```json
// Task Definition
"portMappings": [{"containerPort": 8080}]

// Service load-balancers
"containerPort": 3000  // ❌ 불일치!

// 해결: 포트 일치시키기
```

**B. 헬스체크 경로 없음**
```bash
# ALB Target Group 헬스체크: GET /
# 애플리케이션에 / 엔드포인트 없음

# 해결 1: 애플리케이션에 / 또는 /health 엔드포인트 추가
# 해결 2: Target Group 헬스체크 경로 변경 (인프라 레포에서)
```

**C. 보안 그룹 규칙**
```bash
# ECS Tasks 보안 그룹이 ALB로부터 트래픽을 허용하는지 확인
aws ec2 describe-security-groups --group-ids sg-02e56b242615df825

# Inbound 규칙에 ALB 보안 그룹이 있어야 함:
# Type: Custom TCP
# Port: 8080 (컨테이너 포트)
# Source: sg-071f840190ecf96a1 (ALB 보안 그룹)
```

### 3. 배포 중 다운타임 발생

**원인:**
- `minimumHealthyPercent`가 100 미만
- 헬스체크 grace period 부족

**해결:**
```bash
aws ecs update-service \
  --cluster cat-cluster \
  --service cat-backend-service \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
  --health-check-grace-period-seconds 120
```

### 4. 배포가 멈춤 (Stuck)

**증상:**
```bash
aws ecs describe-services --cluster cat-cluster --services cat-backend-service
# deployments: [
#   {status: "PRIMARY", runningCount: 2, desiredCount: 2},
#   {status: "ACTIVE", runningCount: 2, desiredCount: 2}  # 이전 배포가 안 사라짐
# ]
```

**해결:**
```bash
# Circuit breaker 활성화 (서비스 생성 시)
aws ecs create-service \
  --cluster cat-cluster \
  --service-name cat-backend-service \
  ... \
  --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true}"

# 또는 강제 재배포
aws ecs update-service \
  --cluster cat-cluster \
  --service cat-backend-service \
  --force-new-deployment
```

### 5. ECS Exec 디버깅

컨테이너 내부 접속:
```bash
# ECS Exec 활성화 (서비스 생성 시 --enable-execute-command)

# 태스크 ARN 확인
TASK_ARN=$(aws ecs list-tasks --cluster cat-cluster --service-name cat-backend-service --query 'taskArns[0]' --output text)

# 컨테이너 접속
aws ecs execute-command \
  --cluster cat-cluster \
  --task $TASK_ARN \
  --container backend \
  --interactive \
  --command "/bin/bash"

# 컨테이너 내에서 디버깅
curl http://localhost:8080/health
env | grep DB_
ps aux
```

## 참고 자료

- [ECS Task Definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
- [ECS Services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html)
- [ALB Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [GitHub Actions - Amazon ECS](https://github.com/aws-actions/amazon-ecs-deploy-task-definition)
