# Cat CICD Infrastructure

Terraform을 사용한 Cat CICD 인프라 관리 프로젝트입니다.

## 프로젝트 구조

```
.
├── backend.tf              # Terraform backend 설정 (실제 사용)
├── backend.tf.example      # Terraform backend 설정 예시 파일
├── main.tf                 # 메인 인프라 리소스 정의
├── providers.tf            # Provider 설정
├── variables.tf            # 변수 정의
├── outputs.tf              # Output 값 정의
├── .pre-commit-config.yaml # Pre-commit hooks 설정
├── .tflint.hcl             # TFLint 설정
├── PRE-COMMIT-GUIDE.md     # Pre-commit 가이드
├── modules/                # Terraform 모듈 (선택사항)
└── .github/workflows/      # GitHub Actions 워크플로우
```

## Backend 설정

Terraform은 state 파일을 원격 저장소에 저장하여 팀원들과 안전하게 공유할 수 있습니다.

### Backend 설정 방법

1. `backend.tf.example` 파일을 복사하여 `backend.tf` 파일을 생성합니다:

```bash
cp backend.tf.example backend.tf
```

2. `backend.tf` 파일의 내용:

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

1. **backend.tf 파일 관리**
   - `backend.tf` 파일은 `.gitignore`에 포함되어 있어 Git에 커밋되지 않습니다
   - 각 개발자는 `backend.tf.example`을 복사하여 사용해야 합니다

2. **State 파일 잠금**
   - S3 backend는 DynamoDB를 사용하여 state 잠금을 지원합니다
   - 동시 수정을 방지하려면 DynamoDB 테이블 설정이 필요할 수 있습니다

3. **권한 설정**
   - S3 버킷에 대한 읽기/쓰기 권한이 필요합니다
   - AWS credentials가 올바르게 설정되어 있어야 합니다

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
- **ECR Repositories**: 5개
  - `cat-gateway-api`
  - `cat-reservation-api`
  - `cat-inventory-api`
  - `cat-payment-sim-api`
  - `cat-reservation-worker`

### 로드 밸런서
- **ALB**: HTTP(80) + HTTPS(443)
  - DNS: `cat-alb-*.ap-northeast-2.elb.amazonaws.com`
  - Target Group: `cat-tg` (Health check: `/health`)
- **ACM 인증서**: `*.go-to-learn.net` (HTTPS용)

### 보안
- **Security Groups**: ALB용, ECS Tasks용
- **IAM Roles**: Task Execution Role, Task Role

## 사용 방법

### 1. 인프라 배포

#### Backend 설정

```bash
cp backend.tf.example backend.tf
```

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




### 빠른 시작

```bash
# pre-commit 설치
pip install pre-commit

# hook 활성화
pre-commit install

# 모든 파일 검사
pre-commit run --all-files
```

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
