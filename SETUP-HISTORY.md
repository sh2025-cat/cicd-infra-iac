# Cat CICD 인프라 구축 히스토리

Softbank 2025 해커톤을 위한 AWS ECS 기반 마이크로서비스 인프라 구축 과정을 기록한 문서입니다.

## 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [인프라 아키텍처](#인프라-아키텍처)
3. [구축 과정](#구축-과정)
4. [배포된 리소스](#배포된-리소스)
5. [비용 정보](#비용-정보)
6. [다음 단계](#다음-단계)

---

## 프로젝트 개요

### 목표
- Terraform을 사용한 AWS ECS Fargate 기반 마이크로서비스 인프라 구축
- 코드 품질 관리를 위한 Pre-commit hooks 적용
- HTTPS를 지원하는 ALB 및 도메인 연결
- CI/CD 파이프라인을 위한 ECR 레지스트리 구성

### 기술 스택
- **IaC**: Terraform
- **컨테이너 오케스트레이션**: AWS ECS Fargate
- **컨테이너 레지스트리**: AWS ECR
- **로드 밸런서**: AWS Application Load Balancer (ALB)
- **네트워크**: AWS VPC (Multi-AZ)
- **보안**: ACM 인증서, Security Groups, IAM Roles
- **코드 품질**: Pre-commit hooks, TFLint, tfsec

### 프로젝트 정보
- **리전**: ap-northeast-2 (서울)
- **가용 영역**: ap-northeast-2a, ap-northeast-2c
- **도메인**: go-to-learn.net (Cloudflare DNS)
- **프로젝트명**: cat (Softbank2025-Cat)

---

## 인프라 아키텍처

### 네트워크 구성

```
Internet
    |
    v
Internet Gateway
    |
    v
Public Subnets (2 AZs)
    |
    +-- NAT Gateway
    |
    +-- Application Load Balancer (ALB)
            |
            v
    Private App Subnets (2 AZs)
            |
            v
    ECS Fargate Tasks (5 Services)
            |
            +-- Private DB Subnets (2 AZs)
```

### 서비스 구성

```
Cloudflare DNS (api.go-to-learn.net)
    |
    v
ALB (HTTPS: 443, HTTP: 80)
    |
    v
Target Group (Health Check: /health)
    |
    v
ECS Services:
    - gateway-api
    - reservation-api
    - inventory-api
    - payment-sim-api
    - reservation-worker (백그라운드 작업)
```

### VPC 네트워크

```
VPC: 10.180.0.0/20

Public Subnets:
  - 10.180.0.0/24 (ap-northeast-2a)
  - 10.180.1.0/24 (ap-northeast-2c)

Private App Subnets:
  - 10.180.4.0/22 (ap-northeast-2a)
  - 10.180.8.0/22 (ap-northeast-2c)

Private DB Subnets:
  - 10.180.2.0/24 (ap-northeast-2a)
  - 10.180.3.0/24 (ap-northeast-2c)
```

---

## 구축 과정

### 1단계: 개발 환경 설정

#### Pre-commit Hooks 구성

**목적**: 코드 품질 및 보안 검증 자동화

**작업 내용**:
```bash
# .pre-commit-config.yaml 생성
- terraform_fmt: 코드 포맷팅
- terraform_validate: 문법 검증
- terraform_tflint: 린팅 검사
- terraform_tfsec: 보안 스캔
- terraform_docs: 문서 자동 생성 (선택)

# .tflint.hcl 생성
- AWS 플러그인 활성화
- call_module_type = "all" (v0.59.1 최신 설정)
```

**설치**:
```bash
# Pre-commit 도구 설치
pip install pre-commit
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Pre-commit hooks 활성화
pre-commit install
tflint --init
```

**결과**:
- ✅ 커밋 전 자동 검증
- ✅ 코드 품질 향상
- ✅ 보안 취약점 사전 탐지

#### 파일 이름 표준화

**변경 사항**:
- `var.tf` → `variables.tf` (Terraform 표준 명명 규칙)

---

### 2단계: Terraform State Backend 설정

#### 목적
팀 협업을 위한 Terraform State 원격 저장 및 동시성 제어

#### S3 버킷 생성

```bash
BUCKET_NAME="softbank2025-cat-tfstate"
REGION="ap-northeast-2"

# S3 버킷 생성
aws s3api create-bucket \
  --bucket ${BUCKET_NAME} \
  --region ${REGION} \
  --create-bucket-configuration LocationConstraint=${REGION}

# 버전 관리 활성화
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# 암호화 활성화
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 퍼블릭 액세스 차단
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

#### DynamoDB 테이블 생성

```bash
# State Locking용 DynamoDB 테이블
aws dynamodb create-table \
  --table-name softbank2025-cat-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-2
```

#### IAM 사용자 생성

```bash
# Terraform State 관리용 IAM 사용자
aws iam create-user --user-name terraform-state-manager

# 최소 권한 정책 연결
aws iam attach-user-policy \
  --user-name terraform-state-manager \
  --policy-arn arn:aws:iam::277679348386:policy/Softbank2025-Cat-TerraformState-Policy
```

#### Backend 설정 파일

**backend.tf**:
```hcl
terraform {
  backend "s3" {
    bucket         = "softbank2025-cat-tfstate"
    key            = "cat-cicd/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "softbank2025-cat-tfstate-lock"
    encrypt        = true
  }
}
```

**결과**:
- ✅ State 파일 안전한 원격 저장
- ✅ 팀원 간 State 공유
- ✅ 동시 실행 방지 (DynamoDB Lock)

---

### 3단계: VPC 인프라 배포

#### VPC 모듈 구성

**modules/vpc/**:
- VPC 생성 (10.180.0.0/20)
- Public/Private 서브넷 (Multi-AZ)
- Internet Gateway
- NAT Gateway (비용 발생 주의!)
- Route Tables

**배포**:
```bash
terraform init
terraform plan
terraform apply
```

**배포 결과**:
- VPC ID: `vpc-0a40a72a644f0fcfe`
- 총 21개 리소스 생성
- Public Subnets: 2개
- Private App Subnets: 2개
- Private DB Subnets: 2개
- NAT Gateway: 1개 (약 $42/월)

---

### 4단계: Default VPC 정리

#### 문제 발견
- Default VPC에 삭제 안 되는 리소스 존재
- RDS 인스턴스 (`database-1`) 삭제 중 상태

#### 정리 작업

```bash
# DB Subnet Group 삭제
aws rds delete-db-subnet-group --db-subnet-group-name default

# Security Groups 삭제
aws ec2 delete-security-group --group-id sg-xxxxx  # launch-wizard-1
aws ec2 delete-security-group --group-id sg-xxxxx  # launch-wizard-2

# Default VPC 삭제
aws ec2 delete-vpc --vpc-id vpc-0910295a2b19d89af
```

**결과**:
- ✅ Default VPC 정리 완료
- ✅ 불필요한 리소스 제거

---

### 5단계: ECS 및 ECR 인프라 구축

#### 아키텍처 결정

**원칙**:
- Terraform: 인프라만 관리 (VPC, ECS Cluster, ECR, IAM)
- CI/CD: 애플리케이션 배포 (Docker 이미지, Task Definition, Service)

#### ECR 모듈 생성

**modules/ecr/**:
- 5개 ECR 리포지토리 생성
- Lifecycle 정책 적용:
  - Production 이미지: 최근 10개 유지
  - Development 이미지: 최근 5개 유지
  - Untagged 이미지: 1일 후 삭제

**생성된 리포지토리**:
```
277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api
277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-reservation-api
277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-inventory-api
277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-payment-sim-api
277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-reservation-worker
```

#### ECS 모듈 생성

**modules/ecs/**:

**iam.tf**:
```hcl
# Task Execution Role (ECR pull, CloudWatch logs)
aws_iam_role.ecs_task_execution_role

# Task Role (S3, DynamoDB, SQS, Secrets Manager)
aws_iam_role.ecs_task_role
```

**ecs.tf**:
```hcl
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "cat-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"  # 비용 절감
  }
}
```

**설정**:
- Fargate/Fargate Spot 지원
- CloudWatch Logs 통합
- 로그 보관: 7일

#### Security Groups 모듈

**modules/security-groups/**:

```hcl
# ALB Security Group
- Inbound: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
- Outbound: All

# ECS Tasks Security Group
- Inbound: All from ALB Security Group
- Outbound: All

# RDS Security Group (선택, create_rds=false)
- Inbound: 5432 from ECS Tasks Security Group
```

**결과**:
- ✅ ECS Cluster 생성
- ✅ ECR 리포지토리 5개
- ✅ IAM Roles 분리 (보안)
- ✅ Security Groups 최소 권한

---

### 6단계: ALB 및 HTTPS 설정

#### ALB 모듈 생성

**modules/alb/**:

```hcl
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "cat-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]
}

# Target Group
resource "aws_lb_target_group" "main" {
  name        = "cat-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"  # Fargate 필수

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

# HTTP Listener (포트 80)
resource "aws_lb_listener" "http" {
  port     = 80
  protocol = "HTTP"
}

# HTTPS Listener (포트 443)
resource "aws_lb_listener" "https" {
  port            = 443
  protocol        = "HTTPS"
  certificate_arn = var.certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}
```

#### ACM 인증서 적용

**인증서 정보**:
- ARN: `arn:aws:acm:ap-northeast-2:277679348386:certificate/bcecb1cd-40d9-432c-96fe-76c4d6828d9c`
- 도메인: `*.go-to-learn.net`
- 리전: ap-northeast-2

**terraform.tfvars**:
```hcl
alb_certificate_arn = "arn:aws:acm:ap-northeast-2:277679348386:certificate/bcecb1cd-40d9-432c-96fe-76c4d6828d9c"
```

**결과**:
- ✅ ALB DNS: `cat-alb-1496224480.ap-northeast-2.elb.amazonaws.com`
- ✅ HTTP/HTTPS 리스너 생성
- ✅ TLS 1.3 지원

---

### 7단계: CloudFront 검토 및 제거

#### CloudFront 모듈 생성 (초기)

**시도한 구성**:
- ALB를 Origin으로 하는 CloudFront Distribution
- Custom Domain 지원 (aliases)
- 캐싱 정책 (정적 콘텐츠 vs API)

#### 문제점 발견

**이슈**:
- CloudFront는 us-east-1의 ACM 인증서만 사용 가능
- 기존 인증서는 ap-northeast-2에 생성됨
- 해커톤 기간 동안 CloudFront 불필요

#### 결정 사항

**선택**: CloudFront 모듈 완전 제거, ALB만 사용

**이유**:
- Cloudflare DNS에서 ALB로 직접 연결 가능
- 해커톤에서 글로벌 CDN 불필요
- 인프라 단순화

**제거 작업**:
```bash
# main.tf에서 CloudFront 모듈 제거
# outputs.tf에서 CloudFront 출력 제거
# variables.tf에서 CloudFront 변수 제거
```

**결과**:
- ✅ 인프라 단순화
- ✅ 불필요한 복잡도 제거

---

### 8단계: Cloudflare DNS 연결

#### DNS 설정

**Cloudflare 설정**:
```
Type: CNAME
Name: api
Target: cat-alb-1496224480.ap-northeast-2.elb.amazonaws.com
Proxy status: DNS only (회색 구름) ← 중요!
TTL: Auto
```

**중요 포인트**:
- **Proxy 비활성화 필수**: Cloudflare Proxy를 켜면 ALB 헬스체크 실패
- DNS only 모드로 직접 ALB 연결

#### 테스트 결과

```bash
# DNS 확인
$ host api.go-to-learn.net
api.go-to-learn.net is an alias for cat-alb-1496224480.ap-northeast-2.elb.amazonaws.com.
cat-alb-1496224480.ap-northeast-2.elb.amazonaws.com has address 43.203.9.123

# HTTP 테스트
$ curl -I http://api.go-to-learn.net/health
HTTP/1.1 503 Service Temporarily Unavailable  # Task 없음

# HTTPS 테스트
$ curl -I https://api.go-to-learn.net/health
HTTP/2 503  # TLS 1.3, 인증서 정상!
```

**결과**:
- ✅ DNS 연결 성공
- ✅ HTTP/HTTPS 모두 작동
- ✅ 인증서 정상 적용
- ⚠️ 503 에러는 정상 (ECS Task 미배포)

---

### 9단계: ECS 배포 템플릿 및 스크립트 생성

#### Task Definition 템플릿

**examples/ecs-task-definitions/**:

각 서비스별 Task Definition JSON 파일 생성:
- `gateway-api.json`
- `reservation-api.json`
- `inventory-api.json`
- `payment-sim-api.json`
- `reservation-worker.json`

**공통 설정**:
```json
{
  "family": "cat-gateway-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::277679348386:role/cat-cluster-task-execution-role",
  "taskRoleArn": "arn:aws:iam::277679348386:role/cat-cluster-task-role",
  "containerDefinitions": [
    {
      "name": "gateway-api",
      "image": "277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest",
      "portMappings": [{"containerPort": 80}],
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/cat-gateway-api",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      }
    }
  ]
}
```

#### 배포 스크립트

**examples/scripts/push-to-ecr.sh**:
```bash
#!/bin/bash
# ECR 로그인 → Docker 빌드 → 태그 → 푸시
./push-to-ecr.sh gateway-api ./Dockerfile latest
```

**examples/scripts/deploy-ecs-service.sh**:
```bash
#!/bin/bash
# Task Definition 등록 → Service 생성/업데이트 → ALB 연결
./deploy-ecs-service.sh gateway-api 2  # 2개 Task 실행
```

**주요 기능**:
- Terraform outputs 자동 읽기
- API 서비스는 ALB 자동 연결
- Worker는 ALB 없이 실행
- Service 존재 여부 자동 판단 (create vs update)

#### 문서 작성

**examples/README.md**:
- 배포 프로세스 가이드
- 수동 배포 방법
- Task Definition 커스터마이징
- 모니터링 방법
- CI/CD 통합 예제 (GitHub Actions)

**결과**:
- ✅ 재사용 가능한 Task Definition 템플릿
- ✅ 원클릭 배포 스크립트
- ✅ 상세한 배포 가이드 문서

---

## 배포된 리소스

### 네트워크 (21개 리소스)

| 리소스 | ID/Name | 설명 |
|--------|---------|------|
| VPC | vpc-0a40a72a644f0fcfe | 10.180.0.0/20 |
| Internet Gateway | igw-035015fdc81ea50ce | Public 인터넷 연결 |
| NAT Gateway | nat-0a6fbed8bdc64f6d1 | Private → 인터넷 |
| Elastic IP | eipalloc-02e591e577b83a717 | NAT Gateway용 |
| Public Subnets | subnet-0efaec1854bc707e5<br>subnet-0fc2aaeab9f03e752 | 2a, 2c |
| Private App Subnets | subnet-01b45f063485ebd3a<br>subnet-08aa87aebe215f4dd | 2a, 2c |
| Private DB Subnets | subnet-0408f7b770806a5c6<br>subnet-0d4c72c13832e5085 | 2a, 2c |

### 컨테이너 인프라 (16개 리소스)

#### ECS Cluster
- **Cluster Name**: cat-cluster
- **Cluster ID**: arn:aws:ecs:ap-northeast-2:277679348386:cluster/cat-cluster
- **CloudWatch Logs**: 7일 보관

#### ECR Repositories (5개)
| Repository | URL |
|------------|-----|
| cat-gateway-api | 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api |
| cat-reservation-api | 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-reservation-api |
| cat-inventory-api | 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-inventory-api |
| cat-payment-sim-api | 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-payment-sim-api |
| cat-reservation-worker | 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-reservation-worker |

#### IAM Roles (2개)
- **Task Execution Role**: arn:aws:iam::277679348386:role/cat-cluster-task-execution-role
  - ECR 이미지 Pull
  - CloudWatch Logs 쓰기
- **Task Role**: arn:aws:iam::277679348386:role/cat-cluster-task-role
  - S3 읽기/쓰기
  - DynamoDB 액세스
  - SQS 액세스
  - Secrets Manager 읽기

### 로드 밸런서 (4개 리소스)

| 리소스 | 값 | 설명 |
|--------|-----|------|
| ALB | cat-alb-1496224480.ap-northeast-2.elb.amazonaws.com | Public ALB |
| ARN | arn:aws:elasticloadbalancing:ap-northeast-2:277679348386:loadbalancer/app/cat-alb/6685ab7595bc19c6 | - |
| Target Group | cat-tg | Health check: /health |
| HTTP Listener | 포트 80 | - |
| HTTPS Listener | 포트 443 | TLS 1.3, ACM 인증서 |

### 보안 그룹 (2개 리소스)

| Security Group | ID | 규칙 |
|----------------|-----|------|
| ALB SG | sg-071f840190ecf96a1 | In: 80,443 from 0.0.0.0/0 |
| ECS Tasks SG | sg-02e56b242615df825 | In: All from ALB SG |

### Terraform State 관리

| 리소스 | 이름 | 비용 |
|--------|------|------|
| S3 Bucket | softbank2025-cat-tfstate | ~$0.02/월 |
| DynamoDB Table | softbank2025-cat-tfstate-lock | $0 (사용 없음) |

---

## 비용 정보

### 월간 예상 비용 (24시간 가동 기준)

| 리소스 | 시간당 | 월간 (730h) | 비고 |
|--------|--------|-------------|------|
| **NAT Gateway** | $0.059 | **$43.07** | 가장 큰 비용 |
| NAT 데이터 전송 | $0.126/GB | 변동 | 트래픽 의존 |
| **ALB** | $0.0252 | **$18.40** | - |
| ALB LCU | $0.008/LCU | ~$2 | 트래픽 적으면 미미 |
| **ECS Fargate** | - | **$0** | Task 없음 |
| ECR 스토리지 | $0.10/GB | ~$0 | 이미지 없음 |
| S3 (tfstate) | - | ~$0.02 | - |
| DynamoDB | - | $0 | 사용 없음 |
| **합계** | - | **~$63.49/월** | - |

### 해커톤 1주일 비용

```
$63.49 / 30일 × 7일 = $14.81
약 ₩19,700 (환율 1,330원 기준)
```

### 프리티어 혜택

- ✅ **VPC, Subnets, IGW**: 완전 무료
- ✅ **Security Groups, IAM**: 완전 무료
- ✅ **ECR**: 500MB 무료
- ✅ **S3**: 5GB 무료
- ✅ **CloudWatch Logs**: 5GB 무료
- ❌ **NAT Gateway**: 프리티어 없음
- ❌ **ALB**: 프리티어 없음
- ❌ **ECS Fargate**: 프리티어 없음

### 비용 절감 팁

1. **NAT Gateway 제거** (-$43/월)
   - Private Subnet에서 인터넷 불가
   - ECR Pull 불가 (대안: VPC Endpoint)

2. **사용하지 않을 때 destroy**
   ```bash
   terraform destroy
   ```

3. **Fargate Spot 사용** (이미 적용)
   - 최대 70% 할인

---

## 다음 단계

### 1. 애플리케이션 배포

#### Docker 이미지 빌드

```bash
cd examples/scripts

# 각 서비스별 이미지 빌드 및 푸시
./push-to-ecr.sh gateway-api /path/to/Dockerfile latest
./push-to-ecr.sh reservation-api /path/to/Dockerfile latest
./push-to-ecr.sh inventory-api /path/to/Dockerfile latest
./push-to-ecr.sh payment-sim-api /path/to/Dockerfile latest
./push-to-ecr.sh reservation-worker /path/to/Dockerfile latest
```

#### ECS Service 배포

```bash
# API 서비스 배포 (ALB 연결)
./deploy-ecs-service.sh gateway-api 2
./deploy-ecs-service.sh reservation-api 1
./deploy-ecs-service.sh inventory-api 1
./deploy-ecs-service.sh payment-sim-api 1

# Worker 배포
./deploy-ecs-service.sh reservation-worker 1
```

### 2. 헬스체크 구현

각 애플리케이션에 `/health` 엔드포인트 구현:

```javascript
// Node.js 예시
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});
```

```python
# Python Flask 예시
@app.route('/health')
def health():
    return {'status': 'healthy'}, 200
```

### 3. CI/CD 파이프라인 구축

**GitHub Actions 예제**:

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
            277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest
          docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-gateway-api:latest

      - name: Update ECS Service
        run: |
          aws ecs update-service \
            --cluster cat-cluster \
            --service cat-gateway-api \
            --force-new-deployment
```

### 4. 모니터링 설정

#### CloudWatch Logs

```bash
# 실시간 로그 확인
aws logs tail /ecs/cat-gateway-api --follow

# 최근 1시간 로그
aws logs tail /ecs/cat-gateway-api --since 1h
```

#### ECS Service 모니터링

```bash
# Service 상태
aws ecs describe-services \
  --cluster cat-cluster \
  --services cat-gateway-api

# Task 목록
aws ecs list-tasks \
  --cluster cat-cluster \
  --service-name cat-gateway-api
```

#### ALB 헬스체크

AWS Console → EC2 → Target Groups → cat-tg → Targets 탭

### 5. 데이터베이스 추가 (선택)

현재 DB 서브넷은 준비되어 있지만 RDS는 배포되지 않음.

**RDS 추가 시**:
```hcl
# variables.tf
create_rds = true

# RDS 모듈 추가 필요
```

### 6. 도메인 라우팅 설정

**API Gateway 패턴 (옵션)**:
- `/api/reservation/*` → reservation-api
- `/api/inventory/*` → inventory-api
- `/api/payment/*` → payment-sim-api

**ALB 리스너 규칙으로 구현 가능**

---

## 문제 해결 (Troubleshooting)

### 1. ECS Task가 시작되지 않음

**원인**:
- ECR 이미지가 없음
- IAM 권한 부족
- 서브넷/보안그룹 설정 오류

**해결**:
```bash
# ECR 이미지 확인
aws ecr describe-images \
  --repository-name cat-gateway-api

# IAM Role 확인
aws iam get-role \
  --role-name cat-cluster-task-execution-role

# 서브넷 확인
terraform output private_app_subnet_ids
```

### 2. ALB Health Check 실패

**원인**:
- `/health` 엔드포인트 미구현
- 컨테이너 포트 불일치
- Security Group 차단

**해결**:
```bash
# Security Group 확인
aws ec2 describe-security-groups \
  --group-ids sg-02e56b242615df825

# Target Group 상태
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### 3. 503 에러 지속

**원인**:
- Target Group에 healthy한 Task 없음

**해결**:
```bash
# Task 상태 확인
aws ecs describe-tasks \
  --cluster cat-cluster \
  --tasks <task-id>

# CloudWatch Logs 확인
aws logs tail /ecs/cat-gateway-api --follow
```

### 4. Terraform State Lock 에러

**원인**:
- 이전 실행이 비정상 종료되어 Lock 남아있음

**해결**:
```bash
# DynamoDB에서 Lock 수동 삭제
aws dynamodb delete-item \
  --table-name softbank2025-cat-tfstate-lock \
  --key '{"LockID":{"S":"softbank2025-cat-tfstate/cat-cicd/terraform.tfstate"}}'
```

---

## 참고 자료

### 공식 문서
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [AWS ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
- [Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)

### 프로젝트 문서
- [README.md](./README.md): 프로젝트 전체 개요
- [PRE-COMMIT-GUIDE.md](./PRE-COMMIT-GUIDE.md): Pre-commit hooks 가이드
- [examples/README.md](./examples/README.md): ECS 배포 가이드
- [backend.tf.example](./backend.tf.example): Backend 설정 예제
- [terraform.tfvars.example](./terraform.tfvars.example): 변수 설정 예제

---

## 작업 타임라인

```
2025-11-16
├─ 09:00 Pre-commit hooks 설정
├─ 09:30 Terraform State Backend 구성 (S3 + DynamoDB)
├─ 10:00 VPC 모듈 생성 및 배포 (21개 리소스)
├─ 10:30 Default VPC 정리
├─ 11:00 ECS/ECR 모듈 구성
├─ 12:00 Security Groups 모듈 생성
├─ 13:00 ALB 모듈 생성
├─ 14:00 ACM 인증서 적용 (HTTPS)
├─ 14:30 CloudFront 검토 및 제거 결정
├─ 15:00 Cloudflare DNS 연결 및 테스트
├─ 15:30 ECS Task Definition 템플릿 생성
├─ 16:00 배포 스크립트 작성
└─ 16:30 문서 작성 및 정리
```

---

## 결론

### 달성한 목표

✅ **인프라 코드화 (IaC)**
- Terraform을 통한 완전한 인프라 관리
- 모듈화된 구조로 재사용성 확보

✅ **보안 강화**
- IAM 최소 권한 원칙
- Security Groups 계층화
- ACM 인증서를 통한 HTTPS 지원
- Pre-commit hooks를 통한 보안 스캔

✅ **확장 가능한 아키텍처**
- Multi-AZ 구성
- Auto Scaling 준비 (ECS)
- 마이크로서비스 구조

✅ **운영 효율성**
- CloudWatch Logs 통합
- 원클릭 배포 스크립트
- 상세한 문서화

### 향후 개선 사항

1. **VPC Endpoint 추가** (NAT Gateway 비용 절감)
   - ECR, S3, CloudWatch Logs용 VPC Endpoint

2. **Auto Scaling 설정**
   - CPU/메모리 기반 Auto Scaling
   - 트래픽 기반 Scale Out/In

3. **RDS 추가** (필요 시)
   - Multi-AZ RDS
   - Automated Backups

4. **CI/CD 완전 자동화**
   - GitHub Actions 통합
   - Blue/Green Deployment

5. **모니터링 강화**
   - CloudWatch Dashboards
   - 알람 설정 (SNS)
   - X-Ray 트레이싱

---

**문서 작성일**: 2025-11-16
**프로젝트**: Softbank 2025 Hackathon
**작성자**: Claude Code with Cat CICD Team
