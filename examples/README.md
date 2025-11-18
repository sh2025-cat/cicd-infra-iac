# ECS 배포 가이드

이 디렉토리에는 ECS Task Definition 템플릿과 배포 스크립트가 포함되어 있습니다.

## 디렉토리 구조

```
examples/
├── ecs-task-definitions/       # ECS Task Definition JSON 템플릿
│   ├── gateway-api.json
│   ├── reservation-api.json
│   ├── inventory-api.json
│   ├── payment-sim-api.json
│   └── reservation-worker.json
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

# 예시: Gateway API 배포
./push-to-ecr.sh gateway-api ../../path/to/Dockerfile latest

# 다른 서비스들
./push-to-ecr.sh reservation-api ../../path/to/Dockerfile v1.0.0
./push-to-ecr.sh inventory-api ../../path/to/Dockerfile latest
./push-to-ecr.sh payment-sim-api ../../path/to/Dockerfile latest
./push-to-ecr.sh reservation-worker ../../path/to/Dockerfile latest
```

**스크립트 파라미터:**
- `<service-name>`: 서비스 이름 (gateway-api, reservation-api 등)
- `<dockerfile-path>`: Dockerfile 경로 (기본값: ./Dockerfile)
- `<tag>`: 이미지 태그 (기본값: latest)

### 2. ECS Service 배포

```bash
cd examples/scripts

# API 서비스 배포 (ALB에 연결됨)
./deploy-ecs-service.sh gateway-api 2      # 2개 Task 실행
./deploy-ecs-service.sh reservation-api 1
./deploy-ecs-service.sh inventory-api 1
./deploy-ecs-service.sh payment-sim-api 1

# Worker 배포 (ALB 연결 없음)
./deploy-ecs-service.sh reservation-worker 1
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

```bash
# 빌드
docker build -t cat-gateway-api:latest .

# 태그
docker tag cat-gateway-api:latest \
  277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest

# 푸시
docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest
```

### 3. Task Definition 등록

```bash
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definitions/gateway-api.json
```

### 4. ECS Service 생성

```bash
# Terraform outputs에서 값 가져오기
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SUBNETS=$(terraform output -json private_app_subnet_ids | jq -r 'join(",")')
ECS_SG=$(terraform output -raw ecs_tasks_security_group_id)
TARGET_GROUP_ARN=$(terraform output -raw alb_target_group_arn)

# Service 생성
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name cat-gateway-api \
  --task-definition cat-gateway-api \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers targetGroupArn=$TARGET_GROUP_ARN,containerName=gateway-api,containerPort=80 \
  --health-check-grace-period-seconds 60
```

## Task Definition 커스터마이징

각 서비스의 Task Definition은 `ecs-task-definitions/` 디렉토리에서 수정할 수 있습니다.

### 주요 설정 항목

```json
{
  "cpu": "256",           // vCPU (256 = 0.25 vCPU)
  "memory": "512",        // 메모리 (MB)
  "containerPort": 80,    // 컨테이너 포트
  "environment": [        // 환경 변수
    {
      "name": "ENV",
      "value": "dev"
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

## 모니터링

### Service 상태 확인

```bash
aws ecs describe-services \
  --cluster cat-cluster \
  --services cat-gateway-api
```

### Task 로그 확인

```bash
# 실시간 로그
aws logs tail /ecs/cat-gateway-api --follow

# 최근 로그
aws logs tail /ecs/cat-gateway-api --since 1h
```

### Task 목록 확인

```bash
aws ecs list-tasks --cluster cat-cluster --service-name cat-gateway-api
```

## 트러블슈팅

### 1. Service가 Task를 시작하지 못함

- Task Definition에 이미지 URI 확인
- IAM Role 권한 확인 (ECR pull 권한)
- 서브넷/보안그룹 설정 확인

### 2. Health Check 실패

- 컨테이너 내부에 `/health` 엔드포인트 구현 필요
- Health check 명령어 수정: `healthCheck.command`

### 3. ALB에서 503 에러

- Target Group에 healthy한 Task가 있는지 확인
- 보안그룹에서 ALB → ECS 통신 허용 확인

## CI/CD 통합

GitHub Actions 예제:

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

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
          docker build -t cat-gateway-api:${{ github.sha }} .
          docker tag cat-gateway-api:${{ github.sha }} \
            277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:${{ github.sha }}
          docker tag cat-gateway-api:${{ github.sha }} \
            277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest
          docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:${{ github.sha }}
          docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest

      - name: Update ECS Service
        run: |
          aws ecs update-service \
            --cluster cat-cluster \
            --service cat-gateway-api \
            --force-new-deployment
```

## 참고 자료

- [AWS ECS Fargate 문서](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Task Definition 파라미터](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [ECR 사용자 가이드](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)
