# GitHub Actions 로컬 테스트 가이드

GitHub Actions 워크플로우를 로컬에서 테스트하는 방법을 안내합니다.

## 방법 1: 간단한 스크립트 사용 (권장)

가장 간단하고 빠른 방법입니다. GitHub Actions의 주요 스텝들을 시뮬레이션합니다.

### 사용법

```bash
# 테스트 실행
./scripts/test-workflow-local.sh
```

### 테스트 항목

1. ✓ 필수 도구 확인 (Terraform, AWS CLI)
2. ✓ Terraform Format Check
3. ✓ S3에서 terraform.tfvars 다운로드
4. ✓ Terraform Init
5. ✓ Terraform Validate
6. ✓ Terraform Plan

### 실행 예시

```bash
$ ./scripts/test-workflow-local.sh

========================================
  Local Terraform Workflow Test
========================================

[1/6] Checking required tools...
✓ All required tools are installed

[2/6] Running Terraform Format Check...
✓ Terraform format check passed

[3/6] Downloading terraform.tfvars from S3...
✓ Successfully downloaded terraform.tfvars

[4/6] Running Terraform Init...
✓ Terraform init successful

[5/6] Running Terraform Validate...
✓ Terraform validation passed

[6/6] Running Terraform Plan...
✓ Terraform plan completed successfully

========================================
✓ All workflow tests passed!
========================================
```

## 방법 2: act 도구 사용 (고급)

`act`는 GitHub Actions를 Docker 컨테이너에서 로컬 실행할 수 있게 해주는 도구입니다.

### act 설치

#### Linux

```bash
# Using curl
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Using package manager (Ubuntu/Debian)
sudo apt install act
```

#### macOS

```bash
brew install act
```

#### 확인

```bash
act --version
```

### act 설정

프로젝트에 이미 `.actrc` 설정 파일이 준비되어 있습니다.

#### Secrets 설정

```bash
# .secrets.example을 복사
cp .secrets.example .secrets

# AWS credentials 입력
vim .secrets
```

`.secrets` 파일:
```
AWS_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### act 사용법

#### 워크플로우 목록 보기

```bash
act -l
```

#### 특정 job 실행

```bash
# terraform-validate job 실행
act -j terraform-validate

# terraform-plan job 실행 (Pull Request 이벤트)
act pull_request -j terraform-plan

# terraform-apply job 실행 (Push 이벤트)
act push -j terraform-apply
```

#### Dry run (실제 실행 없이 확인만)

```bash
act -n
```

#### 특정 이벤트로 실행

```bash
# push 이벤트
act push

# pull_request 이벤트
act pull_request

# workflow_dispatch 이벤트
act workflow_dispatch
```

### act 주의사항

1. **Docker 필요**: act는 Docker를 사용하므로 Docker가 설치되어 있어야 합니다
2. **리소스 사용**: Docker 컨테이너가 실행되므로 시스템 리소스를 많이 사용합니다
3. **완전한 재현 불가**: 일부 GitHub Actions 기능은 로컬에서 완전히 재현되지 않을 수 있습니다
4. **AWS 실제 호출**: act로 실행하면 실제 AWS API가 호출됩니다 (주의!)

## 방법 3: 개별 명령어 직접 실행

가장 기본적인 방법으로, 워크플로우의 각 스텝을 직접 실행합니다.

```bash
# 1. Format 체크
terraform fmt -check -recursive

# 2. tfvars 다운로드
./scripts/sync-tfvars.sh download

# 3. Init
terraform init

# 4. Validate
terraform validate

# 5. Plan
terraform plan

# 6. Apply (필요시)
terraform apply
```

## 비교표

| 방법 | 장점 | 단점 | 추천 |
|------|------|------|------|
| **스크립트** | 빠름, 간단함, 설치 불필요 | GitHub Actions와 완전히 동일하지 않음 | ⭐⭐⭐⭐⭐ |
| **act** | GitHub Actions와 유사한 환경 | Docker 필요, 느림, 복잡함 | ⭐⭐⭐ |
| **수동 실행** | 완전한 제어 가능 | 반복 작업이 번거로움 | ⭐⭐ |

## 추천 워크플로우

### 일상적인 개발

```bash
# 1. 코드 수정
vim main.tf

# 2. 포맷
terraform fmt -recursive

# 3. 로컬 테스트
./scripts/test-workflow-local.sh

# 4. Git commit & push
git add .
git commit -m "feat: Add new resource"
git push
```

### Pull Request 전

```bash
# 전체 워크플로우 시뮬레이션
./scripts/test-workflow-local.sh

# act로 한 번 더 검증 (선택사항)
act pull_request -j terraform-plan
```

## 트러블슈팅

### "terraform.tfvars not found"

```bash
# S3에서 다운로드
./scripts/sync-tfvars.sh download
```

### "AWS credentials not configured"

```bash
# AWS CLI 설정 확인
aws configure list

# credentials 재설정
aws configure
```

### "Terraform state locked"

```bash
# DynamoDB에서 lock 확인
aws dynamodb scan --table-name softbank2025-cat-tfstate-lock

# 필요시 강제 unlock (주의!)
terraform force-unlock <LOCK_ID>
```

## 참고 자료

- [act GitHub Repository](https://github.com/nektos/act)
- [Terraform CLI Documentation](https://www.terraform.io/cli)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
