# Cat CICD Infrastructure

Terraform을 사용한 Cat CICD 인프라 관리 프로젝트입니다.

## 프로젝트 구조

```
.
├── backend.tf              # Terraform backend 설정
├── main.tf                 # 메인 인프라 리소스 정의
├── providers.tf            # Provider 설정
├── variables.tf            # 변수 정의
├── outputs.tf              # Output 값 정의
├── .pre-commit-config.yaml # Pre-commit hooks 설정
├── .tflint.hcl             # TFLint 설정
├── infrastructure.drawio   # 인프라 아키텍처 다이어그램
├── README.md               # 프로젝트 설명
├── ARCHITECTURE.md         # 인프라 아키텍처 문서
├── PRE-COMMIT-GUIDE.md     # Pre-commit 가이드
├── SETUP-HISTORY.md        # 인프라 설정 히스토리
├── SETUP-CREDENTIALS.md    # AWS 자격증명 설정 가이드
├── modules/                # Terraform 모듈
│   ├── vpc/                # VPC 및 네트워크 구성
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── alb/                # Application Load Balancer
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── ecs/                # ECS Cluster 및 Task 정의
│   │   ├── main.tf
│   │   ├── iam.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── ecr/                # ECR 리포지토리
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── cloudwatch-logs/   # CloudWatch Log Groups
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── cloudfront/         # CloudFront 배포
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── waf/                # WAF Web ACL
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── bastion/            # Bastion Host
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   └── security-groups/    # 보안 그룹
│       ├── main.tf
│       ├── outputs.tf
│       ├── variables.tf
│       └── versions.tf
├── examples/               # 예시 파일
│   ├── README.md
│   ├── ecs-task-definitions/
│   │   ├── backend.json    # Backend API Task Definition
│   │   └── frontend.json   # Frontend Task Definition
│   └── scripts/
│       ├── deploy-ecs-service.sh  # ECS 서비스 배포 스크립트
│       └── push-to-ecr.sh         # ECR 이미지 푸시 스크립트
└── .github/workflows/      # GitHub Actions 워크플로우
    └── terrafm.yml         # Terraform CI/CD 워크플로우
```

## Backend 설정

Terraform은 state 파일을 원격 저장소에 저장하여 팀원들과 안전하게 공유할 수 있습니다.

### Backend 설정 방법

`backend.tf` 파일에 S3 backend가 설정되어 있습니다:

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

### Backend 설정 파라미터 설명

- **bucket**: Terraform state 파일을 저장할 S3 버킷 이름
  - 예시: `softbank2025-cat-tfstate`
  - 팀 전체가 공유하는 버킷이어야 합니다

- **key**: S3 버킷 내에서 state 파일이 저장될 경로
  - 예시: `cat-cicd/terraform.tfstate`
  - 프로젝트/환경별로 구분하여 관리합니다
  - 패턴: `<project-name>/<environment>/terraform.tfstate`

- **region**: S3 버킷이 위치한 AWS 리전
  - 예시: `ap-northeast-2` (서울 리전)

- **dynamodb_table**: State locking을 위한 DynamoDB 테이블 이름
  - 예시: `softbank2025-cat-tfstate-lock`
  - 동시 실행 방지를 위해 필수

- **encrypt**: State 파일 암호화 활성화
  - 값: `true` (권장)

### Backend 초기화

backend 설정 후 Terraform을 초기화합니다:

```bash
terraform init
```

기존 로컬 state를 원격 backend로 마이그레이션하려면:

```bash
terraform init -migrate-state
```

### 주의사항

1. **State 파일 잠금**
   - S3 backend는 DynamoDB를 사용하여 state 잠금을 지원합니다
   - 동시 수정을 방지하려면 DynamoDB 테이블 설정이 필요합니다

2. **권한 설정**
   - S3 버킷에 대한 읽기/쓰기 권한이 필요합니다
   - AWS credentials가 올바르게 설정되어 있어야 합니다

## Terraform Variables 관리 (S3)

민감한 정보(DB 비밀번호 등)를 포함하는 `terraform.tfvars` 파일은 S3에 저장되어 관리됩니다.

### S3 저장 위치

```
s3://softbank2025-cat-tfstate/cat-cicd/terraform.tfvars
```

### 로컬 개발 시 사용법

#### 1. S3에서 다운로드

```bash
# 스크립트 사용 (권장)
./scripts/sync-tfvars.sh download

# 또는 직접 AWS CLI 사용
aws s3 cp s3://softbank2025-cat-tfstate/cat-cicd/terraform.tfvars ./terraform.tfvars
```

#### 2. 변수 수정 후 S3에 업로드

```bash
# terraform.tfvars 파일 수정 후
vim terraform.tfvars

# S3에 업로드
./scripts/sync-tfvars.sh upload

# 또는 직접 AWS CLI 사용
aws s3 cp ./terraform.tfvars s3://softbank2025-cat-tfstate/cat-cicd/terraform.tfvars
```

### GitHub Actions 자동 다운로드

GitHub Actions 워크플로우는 자동으로 S3에서 `terraform.tfvars`를 다운로드합니다.

```yaml
- name: Download terraform.tfvars from S3
  run: |
    aws s3 cp s3://softbank2025-cat-tfstate/cat-cicd/terraform.tfvars ./terraform.tfvars
```

### 보안 주의사항

- `terraform.tfvars` 파일은 `.gitignore`에 추가되어 Git에 커밋되지 않습니다
- S3 버킷 접근 권한이 있는 사용자만 변수 파일을 다운로드/수정할 수 있습니다
- GitHub Actions는 AWS credentials를 통해 S3에 접근합니다

## 사전 요구사항

### 1. 기본 도구 설치

- Terraform >= 1.5.0
- AWS CLI 설정 완료

```bash
# AWS CLI 설치 확인
aws --version

# AWS 자격증명 구성
aws configure
```

### 2. Terraform State 저장을 위한 S3 버킷 및 DynamoDB 테이블 생성

Terraform state 파일을 안전하게 저장하고 동시 실행을 방지하기 위해 S3 버킷과 DynamoDB 테이블을 **먼저 수동으로 생성**해야 합니다.

#### S3 버킷 생성

```bash
# 버킷 이름 설정 (고유한 이름이어야 함)
BUCKET_NAME="softbank2025-cat-tfstate"
REGION="ap-northeast-2"

# S3 버킷 생성
aws s3api create-bucket \
  --bucket ${BUCKET_NAME} \
  --region ${REGION} \
  --create-bucket-configuration LocationConstraint=${REGION}

# 버킷 버전 관리 활성화 (상태 파일 복구를 위해 권장)
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# 버킷 암호화 활성화
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 퍼블릭 액세스 차단 (보안)
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

#### DynamoDB 테이블 생성 (State Locking용)

```bash
# DynamoDB 테이블 생성
aws dynamodb create-table \
  --table-name softbank2025-cat-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${REGION}
```

### 3. Pre-commit Hooks 설정 (개발자용)

코드 품질과 보안을 유지하기 위해 pre-commit hooks를 사용합니다.

```bash
# pre-commit 설치
pip install pre-commit

# TFLint 설치
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec 설치 (선택사항 - 보안 스캔)
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# terraform-docs 설치 (선택사항 - 문서 자동 생성)
curl -Lo /tmp/terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.17.0/terraform-docs-v0.17.0-linux-amd64.tar.gz
tar -xzf /tmp/terraform-docs.tar.gz -C /tmp
sudo mv /tmp/terraform-docs /usr/local/bin/

# pre-commit hooks 설치
pre-commit install

# TFLint 플러그인 초기화
tflint --init
```

자세한 내용은 [PRE-COMMIT-GUIDE.md](./PRE-COMMIT-GUIDE.md)를 참고하세요.

## 배포된 인프라

Terraform으로 배포되는 AWS 리소스:

### 네트워크
- **VPC**: `10.180.0.0/20`
- **Public Subnets**: 2개 (ap-northeast-2a, 2c)
- **Private App Subnets**: 2개 (ECS Tasks용)
- **Private DB Subnets**: 2개 (데이터베이스용)
- **NAT Gateway**: 1개
- **Internet Gateway**: 1개

### 컨테이너 인프라
- **ECS Cluster**: `cat-cluster` (Fargate)
- **ECR Repositories**: 2개
  - `cat-backend` (Backend API)
  - `cat-frontend` (Frontend)
- **CloudWatch Log Groups**: ECS Task 로깅
  - `/ecs/cat-backend` - Backend 애플리케이션 로그
  - `/ecs/cat-frontend` - Frontend 애플리케이션 로그
  - 로그 보존 기간: 7일 (기본값, 설정 가능)
  - Terraform으로 사전 생성 (권한 문제 방지)

**참고**: ECS Services와 Task Definitions은 애플리케이션 레포지토리에서 관리합니다. [ECS-DEPLOYMENT-GUIDE.md](./ECS-DEPLOYMENT-GUIDE.md) 참고

### 로드 밸런서
- **ALB**: HTTP(80) + HTTPS(443)
  - DNS: `cat-alb-*.ap-northeast-2.elb.amazonaws.com`
  - Host-based 라우팅 지원
- **Target Groups** (Blue/Green 배포 지원):
  - **Backend Blue** (Active): 포트 **8080** (Health check: `/` on port 8080)
    - Name: `cat-backend-blue-tg`
    - Domain: `cicd-api.go-to-learn.net`
    - 현재 프로덕션 트래픽 수신 중
  - **Backend Green** (Standby): 포트 **8080** (Health check: `/` on port 8080)
    - Name: `cat-backend-green-tg`
    - 새 버전 배포 및 테스트용
  - **Frontend Blue** (Active): 포트 **3000** (Health check: `/` on port 3000)
    - Name: `cat-frontend-blue-tg`
    - Domain: `cicd.go-to-learn.net`
    - 현재 프로덕션 트래픽 수신 중
  - **Frontend Green** (Standby): 포트 **3000** (Health check: `/` on port 3000)
    - Name: `cat-frontend-green-tg`
    - 새 버전 배포 및 테스트용
  - 포트 설정: `terraform.tfvars`에서 `backend_port`, `frontend_port` 변수로 제어

**Blue/Green 배포 방법:**
1. Green Target Group에 새 버전 배포
2. Green에서 헬스체크 통과 확인
3. Listener Rule의 target_group_arn을 Green으로 변경
4. 문제 발생 시 Blue로 즉시 롤백 가능

- **ACM 인증서 (ap-northeast-2)**: `*.go-to-learn.net` (ALB HTTPS용)

### CloudFront (선택사항)
- **배포 여부**: `create_cloudfront = true/false`로 제어
- **Origin**: ALB
- **Cache TTL**: 0 (캐싱 없음)
- **지원 도메인**: `cicd-api.go-to-learn.net`, `cicd.go-to-learn.net`
- **ACM 인증서 (us-east-1)**: CloudFront용 인증서 (US-EAST-1 리전 필수)
- **사용 목적**:
  - Global CDN 배포
  - DDoS 보호 (AWS Shield Standard 자동 적용)
  - WAF 연동 가능
  - HTTPS 강제 (redirect-to-https)

**DNS 설정 (Cloudflare):**
```
cicd-api.go-to-learn.net  → CNAME → <cloudfront_domain_name>
cicd.go-to-learn.net      → CNAME → <cloudfront_domain_name>
```

CloudFront DNS는 `terraform output cloudfront_domain_name`으로 확인 가능

### WAF (Web Application Firewall)
- **배포 여부**: `create_waf = true/false`로 제어
- **적용 대상**: CloudFront Distribution
- **리전**: US-EAST-1 (CloudFront용 WAF는 us-east-1에서만 생성 가능)
- **보호 규칙**:
  - **AWS Managed Rules - Common Rule Set**: 일반적인 웹 공격 차단 (OWASP Top 10)
  - **AWS Managed Rules - Known Bad Inputs**: 알려진 악성 입력 패턴 차단
  - **AWS Managed Rules - SQL Injection**: SQL Injection 공격 차단
  - **Rate Limiting**: IP당 5분에 2000개 요청 제한 (DDoS 방어)
- **비용 최적화**:
  - CloudWatch 메트릭: 비활성화 (`waf_enable_cloudwatch_metrics = false`)
  - 샘플 요청: 비활성화 (`waf_enable_sampled_requests = false`)
  - AWS Managed Rules는 무료 (WAF 요청 비용만 발생)

**WAF 설정 확인:**
```bash
# WAF Web ACL ID 확인
terraform output waf_web_acl_id

# WAF Web ACL ARN 확인
terraform output waf_web_acl_arn
```

**보호 기능:**
- SQL Injection, XSS, CSRF 등 일반적인 웹 공격 차단
- 알려진 악성 봇 및 스캐너 차단
- DDoS 공격 방어 (Rate Limiting)
- 실시간 위협 차단

### Bastion Host (선택사항)
- **배포 여부**: `create_bastion = true/false`로 제어
- **위치**: Public Subnet (SSH 접근 가능)
- **용도**: Private 리소스(RDS, ECS Tasks)에 안전하게 접근
- **인스턴스 타입**: t3.micro (기본값)
- **Elastic IP**: 고정 Public IP 할당
- **SSH Key**: 사전에 AWS에 생성된 Key Pair 사용 (`bastion_key_name`)
- **보안**: SSH 접근 제한 가능 (`bastion_allowed_cidr_blocks`)

**사전 준비사항:**
```bash
# 1. EC2 Key Pair 생성 (AWS Console 또는 CLI)
aws ec2 create-key-pair \
  --key-name cat-bastion-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/cat-bastion-key.pem

# 2. Private key 파일 권한 설정
chmod 400 ~/.ssh/cat-bastion-key.pem

# 3. terraform.tfvars에 Key Pair 이름 설정
# bastion_key_name = "cat-bastion-key"
```

**SSH 접속:**
```bash
# Bastion IP 확인
terraform output bastion_public_ip

# SSH 접속
ssh -i ~/.ssh/cat-bastion-key.pem ec2-user@<BASTION_IP>

# RDS 접속 (Bastion을 통해)
ssh -i ~/.ssh/cat-bastion-key.pem ec2-user@<BASTION_IP>
mysql -h <RDS_ENDPOINT> -u admin -p
```

**주의사항:**
- Bastion 배포 전에 반드시 EC2 Key Pair를 먼저 생성해야 함
- Private key 파일은 안전하게 보관 필요 (분실 시 복구 불가)
- 프로덕션 환경에서는 `bastion_allowed_cidr_blocks`로 IP 제한 권장

### 보안
- **Security Groups**: ALB용, ECS Tasks용, Bastion용
- **IAM Roles**: Task Execution Role, Task Role
- **WAF**: CloudFront용 Web Application Firewall (선택사항)
- **Bastion Host**: Private 리소스 안전 접근 (선택사항)

## 사용 방법

### 1. 인프라 배포

#### Terraform 초기화 및 배포

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

#### 배포 결과 확인

```bash
# ALB DNS name 확인
terraform output alb_dns_name

# ECR 리포지토리 목록
terraform output ecr_repositories
```

### 2. 도메인 설정

ALB는 Host-based 라우팅을 사용하여 도메인별로 다른 타겟 그룹으로 트래픽을 전달합니다.

#### 도메인 구성

기본 도메인 설정 (`terraform.tfvars` 또는 `variables.tf`에서 변경 가능):
- **Backend API**: `cicd-api.go-to-learn.net`
- **Frontend**: `cicd.go-to-learn.net`

#### DNS 설정

Route 53 또는 외부 DNS 서비스에서 다음과 같이 CNAME 레코드를 추가합니다:

```
cicd-api.go-to-learn.net  → CNAME → <ALB_DNS_NAME>
cicd.go-to-learn.net      → CNAME → <ALB_DNS_NAME>
```

ALB DNS Name은 다음 명령으로 확인할 수 있습니다:
```bash
terraform output alb_dns_name
```

#### HTTPS 설정 (선택사항)

HTTPS를 사용하려면 ACM(AWS Certificate Manager)에서 인증서를 발급받고 `terraform.tfvars`에 ARN을 설정합니다:

```hcl
# terraform.tfvars
alb_certificate_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxx"
```

#### 커스텀 도메인 사용

다른 도메인을 사용하려면 `terraform.tfvars`에서 변경 가능합니다:

```hcl
# terraform.tfvars
backend_domain  = "api.yourdomain.com"
frontend_domain = "app.yourdomain.com"
```

### 3. 애플리케이션 배포

이 인프라 레포는 **인프라 리소스만 관리**합니다 (VPC, ALB, ECS Cluster, ECR, RDS).

ECS 애플리케이션(Task Definition, Service)은 **각 애플리케이션 레포지토리에서 배포**합니다.

**자세한 배포 가이드: [ECS-DEPLOYMENT-GUIDE.md](./ECS-DEPLOYMENT-GUIDE.md)**

이 가이드에서 다루는 내용:
- ALB와 ECS Service 연결 방법
- Task Definition 작성
- GitHub Actions로 자동 배포
- 헬스체크 설정
- 롤백 방법
- 트러블슈팅

**빠른 시작 (애플리케이션 레포에서):**
```bash
# 1. ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com

# 2. 이미지 빌드 및 푸시
docker build -t cat-backend .
docker tag cat-backend:latest 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest
docker push 277679348386.dkr.ecr.ap-northeast-2.amazonaws.com/cat-backend:latest

# 3. ECS Service 생성 (최초 1회)
aws ecs create-service --cli-input-json file://service-definition.json

# 4. 이후 배포는 GitHub Actions 자동화
git push origin main
```

### 빠른 시작

```bash
# pre-commit 설치
pip install pre-commit

# hook 활성화
pre-commit install

# 모든 파일 검사
pre-commit run --all-files
```

## 로컬에서 GitHub Actions 테스트

배포 전에 로컬에서 워크플로우를 테스트할 수 있습니다.

### 빠른 테스트 (권장)

```bash
./scripts/test-workflow-local.sh
```

이 스크립트는 다음을 자동으로 실행합니다:
- Terraform format 체크
- S3에서 terraform.tfvars 다운로드
- Terraform init, validate, plan

자세한 내용은 [LOCAL-TESTING-GUIDE.md](./LOCAL-TESTING-GUIDE.md)를 참고하세요.

## CI/CD

GitHub Actions를 통해 자동으로 Terraform 검증 및 배포를 수행합니다.

### Workflow 동작

- **Push 시**: Terraform fmt, validate 검사
- **PR 시**: Terraform plan 실행 및 결과를 PR에 코멘트
- **Main 브랜치 Push 시**: Terraform apply 자동 실행 (production environment)
- **수동 실행 (workflow_dispatch)**: Terraform destroy

### GitHub Secrets 설정

GitHub Actions에서 AWS 리소스를 관리하기 위해 다음 Secrets를 설정해야 합니다.

리포지토리 설정 > Settings > Secrets and variables > Actions > New repository secret

| Secret 이름 | 설명 | 예시 값 |
|------------|------|---------|
| `AWS_ACCESS_KEY` | AWS IAM 사용자의 Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_KEY` | AWS IAM 사용자의 Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

#### AWS IAM 사용자 권한 요구사항

GitHub Actions에서 사용할 IAM 사용자는 다음 권한이 필요합니다:

**필수 권한**:
- `AmazonVPCFullAccess` - VPC, 서브넷, 라우팅 테이블 관리
- `AmazonECS_FullAccess` - ECS 클러스터, 서비스, 태스크 관리
- `AmazonEC2ContainerRegistryFullAccess` - ECR 리포지토리 관리
- `ElasticLoadBalancingFullAccess` - ALB 및 타겟 그룹 관리
- `CloudFrontFullAccess` - CloudFront 배포 관리
- `IAMFullAccess` - ECS Task Role 및 Execution Role 관리
- `AmazonS3FullAccess` - Terraform state 파일 접근 (S3 backend)
- `AmazonDynamoDBFullAccess` - Terraform state locking (DynamoDB)

**커스텀 정책 (권장)**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "ecr:*",
        "elasticloadbalancing:*",
        "cloudfront:*",
        "iam:*",
        "s3:*",
        "dynamodb:*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### IAM 사용자 생성 방법

```bash
# IAM 사용자 생성
aws iam create-user --user-name github-actions-terraform

# Access Key 생성
aws iam create-access-key --user-name github-actions-terraform

# 필요한 정책 연결 (예시)
aws iam attach-user-policy \
  --user-name github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

aws iam attach-user-policy \
  --user-name github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### GitHub Environment 설정

`production` environment를 설정하여 배포 시 수동 승인을 요구할 수 있습니다.

1. Settings > Environments > New environment
2. Environment name: `production`
3. Protection rules:
   - ✅ Required reviewers (배포 전 승인 필요)
   - ✅ Wait timer (배포 전 대기 시간 설정 가능)

## 참고 자료

- [Terraform S3 Backend 문서](https://www.terraform.io/docs/language/settings/backends/s3.html)
