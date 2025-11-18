# ECS 배포 가이드

이 디렉토리에는 ECS Task Definition 템플릿과 배포 스크립트가 포함되어 있습니다.

## 디렉토리 구조

```
examples/
├── ecs-task-definitions/       # ECS Task Definition JSON 템플릿
│   ├── backend.json           # Backend API Task Definition
│   └── frontend.json          # Frontend Task Definition
├── scripts/                    # 배포 스크립트
│   ├── push-to-ecr.sh         # ECR에 Docker 이미지 푸시
│   └── deploy-ecs-service.sh  # ECS Service 배포
└── README.md                   # 이 파일
```

## 사전 요구사항

1. **Terraform 인프라 배포 완료**
   ```bash
   cd ..
   terraform apply
   ```

2. **AWS CLI 설정**
   ```bash
   aws configure
   ```

3. **Docker 설치**

## 배포 프로세스

### 1. Docker 이미지 빌드 및 ECR 푸시

```bash
cd examples/scripts

# Backend API 배포
./push-to-ecr.sh backend ../../path/to/backend/Dockerfile latest

# Frontend 배포
./push-to-ecr.sh frontend ../../path/to/frontend/Dockerfile latest
```

**스크립트 파라미터:**
- `<service-name>`: 서비스 이름 (backend, frontend)
- `<dockerfile-path>`: Dockerfile 경로 (기본값: ./Dockerfile)
- `<tag>`: 이미지 태그 (기본값: latest)

### 2. ECS Service 배포

```bash
cd examples/scripts

# Backend API 배포 (ALB에 연결됨)
./deploy-ecs-service.sh backend 2      # 2개 Task 실행

# Frontend 배포 (ALB에 연결됨)
./deploy-ecs-service.sh frontend 2     # 2개 Task 실행
```

**스크립트 파라미터:**
- `<service-name>`: 서비스 이름
- `<desired-count>`: 실행할 Task 개수 (기본값: 1)

## 수동 배포 (AWS CLI)

스크립트를 사용하지 않고 수동으로 배포하려면:

### 1. ECR 로그인

```bash
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com
```

### 2. Docker 이미지 빌드 및 푸시

#### Backend

```bash
# 빌드
docker build -t cat-backend:latest ./backend

# 태그
docker tag cat-backend:latest \
  277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest

# 푸시
docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest
```

#### Frontend

```bash
# 빌드
docker build -t cat-frontend:latest ./frontend

# 태그
docker tag cat-frontend:latest \
  277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-frontend:latest

# 푸시
docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-frontend:latest
```

### 3. Task Definition 등록

```bash
# Backend Task Definition
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definitions/backend.json

# Frontend Task Definition
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definitions/frontend.json
```

### 4. ECS Service 생성

```bash
# Terraform outputs에서 값 가져오기
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SUBNETS=$(terraform output -json private_app_subnet_ids | jq -r 'join(",")')
ECS_SG=$(terraform output -raw ecs_tasks_security_group_id)
TARGET_GROUP_ARN=$(terraform output -raw alb_target_group_arn)

# Backend Service 생성
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name cat-backend \
  --task-definition cat-backend \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers targetGroupArn=$TARGET_GROUP_ARN,containerName=backend,containerPort=8080 \
  --health-check-grace-period-seconds 60

# Frontend Service 생성
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name cat-frontend \
  --task-definition cat-frontend \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers targetGroupArn=$TARGET_GROUP_ARN,containerName=frontend,containerPort=3000 \
  --health-check-grace-period-seconds 60
```

## Task Definition 커스터마이징

각 서비스의 Task Definition은 `ecs-task-definitions/` 디렉토리에서 수정할 수 있습니다.

### 주요 설정 항목

#### Backend (backend.json)

```json
{
  "cpu": "256",           // vCPU (256 = 0.25 vCPU)
  "memory": "512",        // 메모리 (MB)
  "containerPort": 8080,  // 컨테이너 포트
  "environment": [        // 환경 변수
    {
      "name": "DB_HOST",
      "value": "cat-mysql.xxx.ap-northeast-2.rds.amazonaws.com"
    },
    {
      "name": "DB_PORT",
      "value": "3306"
    }
  ]
}
```

#### Frontend (frontend.json)

```json
{
  "cpu": "256",           // vCPU (256 = 0.25 vCPU)
  "memory": "512",        // 메모리 (MB)
  "containerPort": 3000,  // 컨테이너 포트 (React 기본)
  "environment": [        // 환경 변수
    {
      "name": "REACT_APP_API_URL",
      "value": "http://cat-alb-xxx.ap-northeast-2.elb.amazonaws.com"
    }
  ]
}
```

### CPU/메모리 조합 (Fargate)

| vCPU | 메모리 (GB) |
|------|-------------|
| 0.25 | 0.5, 1, 2   |
| 0.5  | 1, 2, 3, 4  |
| 1    | 2, 3, 4, 5, 6, 7, 8 |
| 2    | 4 ~ 16      |
| 4    | 8 ~ 30      |

## 환경 변수 설정

### Backend 환경 변수

배포 후 RDS 엔드포인트를 확인하여 Task Definition을 업데이트하세요:

```bash
# RDS 엔드포인트 확인
terraform output rds_instance_endpoint

# Task Definition 업데이트
# backend.json에서 DB_HOST 값을 실제 RDS 엔드포인트로 변경
```

### Frontend 환경 변수

ALB DNS를 확인하여 API URL을 설정하세요:

```bash
# ALB DNS 확인
terraform output alb_dns_name

# Task Definition 업데이트
# frontend.json에서 REACT_APP_API_URL 값을 실제 ALB DNS로 변경
```

## 모니터링

### Service 상태 확인

```bash
# Backend Service 상태
aws ecs describe-services \
  --cluster cat-cluster \
  --services cat-backend

# Frontend Service 상태
aws ecs describe-services \
  --cluster cat-cluster \
  --services cat-frontend
```

### Task 로그 확인

```bash
# Backend 실시간 로그
aws logs tail /ecs/cat-backend --follow

# Frontend 실시간 로그
aws logs tail /ecs/cat-frontend --follow

# 최근 1시간 로그
aws logs tail /ecs/cat-backend --since 1h
aws logs tail /ecs/cat-frontend --since 1h
```

### Task 목록 확인

```bash
# Backend Tasks
aws ecs list-tasks --cluster cat-cluster --service-name cat-backend

# Frontend Tasks
aws ecs list-tasks --cluster cat-cluster --service-name cat-frontend
```

## 트러블슈팅

### 1. Service가 Task를 시작하지 못함

- Task Definition에 이미지 URI 확인
- IAM Role 권한 확인 (ECR pull 권한)
- 서브넷/보안그룹 설정 확인

### 2. Health Check 실패

Backend:
- `/health` 엔드포인트가 8080 포트에서 응답하는지 확인
- 데이터베이스 연결 확인

Frontend:
- 3000 포트에서 응답하는지 확인
- 빌드가 정상적으로 완료되었는지 확인

### 3. ALB에서 503 에러

- Target Group에 healthy한 Task가 있는지 확인
- 보안그룹에서 ALB → ECS 통신 허용 확인 (Backend: 8080, Frontend: 3000)

### 4. Backend가 데이터베이스에 연결하지 못함

- RDS 보안 그룹에서 ECS Tasks로부터의 3306 포트 접근 허용 확인
- DB_HOST, DB_PORT, DB_NAME 환경 변수 확인
- RDS 인스턴스가 실행 중인지 확인

## CI/CD 통합

GitHub Actions 예제:

```yaml
name: Deploy Backend to ECS

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region ap-northeast-2 | \
            docker login --username AWS --password-stdin 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com

      - name: Build and Push
        run: |
          docker build -t cat-backend:${{ github.sha }} ./backend
          docker tag cat-backend:${{ github.sha }} \
            277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:${{ github.sha }}
          docker tag cat-backend:${{ github.sha }} \
            277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest
          docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:${{ github.sha }}
          docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest

      - name: Update ECS Service
        run: |
          aws ecs update-service \
            --cluster cat-cluster \
            --service cat-backend \
            --force-new-deployment
```

## 참고 자료

- [AWS ECS Fargate 문서](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Task Definition 파라미터](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [ECR 사용자 가이드](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
