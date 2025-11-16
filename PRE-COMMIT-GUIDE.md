# Pre-commit Hooks 가이드

이 프로젝트는 Terraform 코드의 품질과 보안을 보장하기 위해 pre-commit hooks를 사용합니다.

## 📋 포함된 Hooks

### Terraform 관련
- **terraform_fmt**: 코드를 표준 형식으로 자동 포맷팅
- **terraform_validate**: Terraform 구성 파일의 유효성 검사
- **terraform_docs**: README.md에 자동으로 문서 생성
- **terraform_tflint**: 코드 품질 및 모범 사례 검사
- **terraform_tfsec**: 보안 취약점 검사

### 일반 파일 검사
- **end-of-file-fixer**: 파일 끝에 빈 줄 추가
- **trailing-whitespace**: 후행 공백 제거
- **check-yaml**: YAML 구문 검사
- **check-added-large-files**: 대용량 파일 체크 (500KB 초과)
- **check-merge-conflict**: merge conflict 마커 체크

## 🚀 설치 방법

### 1. Python 및 pre-commit 설치

```bash
# Python 3가 설치되어 있는지 확인
python3 --version

# pre-commit 설치
pip install pre-commit

# 또는 (macOS)
brew install pre-commit
```

### 2. 필요한 도구 설치

#### Terraform
```bash
# macOS
brew install terraform

# 또는 tfenv 사용
brew install tfenv
tfenv install latest
```

#### TFLint
```bash
# macOS
brew install tflint

# Linux
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

#### tfsec
```bash
# macOS
brew install tfsec

# Linux
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

#### terraform-docs
```bash
# macOS
brew install terraform-docs

# Linux
curl -Lo ./terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.17.0/terraform-docs-v0.17.0-linux-amd64.tar.gz
tar -xzf terraform-docs.tar.gz
chmod +x terraform-docs
sudo mv terraform-docs /usr/local/bin/
```

### 3. Pre-commit Hooks 설치

프로젝트 루트 디렉토리에서:

```bash
# pre-commit hooks 설치
pre-commit install

# 설치 확인
pre-commit --version
```

## 📝 사용 방법

### 자동 실행 (권장)
Pre-commit hooks가 설치되면 `git commit` 시 자동으로 실행됩니다:

```bash
git add .
git commit -m "feat: 새로운 기능 추가"
# → pre-commit hooks가 자동으로 실행됩니다
```

### 수동 실행
특정 파일이나 모든 파일에 대해 수동으로 실행할 수 있습니다:

```bash
# 모든 파일에 대해 실행
pre-commit run --all-files

# 스테이징된 파일에만 실행
pre-commit run

# 특정 hook만 실행
pre-commit run terraform_fmt --all-files
```

## 🔧 TFLint 설정

`.tflint.hcl` 파일을 프로젝트 루트에 생성하세요:

```hcl
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  module = true
  force = false
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}
```

## ❓ 문제 해결

### Hook 실행 실패 시

```bash
# pre-commit 캐시 정리
pre-commit clean

# hooks 재설치
pre-commit uninstall
pre-commit install

# 최신 버전으로 업데이트
pre-commit autoupdate
```

### Terraform 초기화 필요 시

```bash
# 각 Terraform 디렉토리에서
terraform init
```

### 특정 Hook 건너뛰기 (긴급 상황)

```bash
# 모든 hooks 건너뛰기 (권장하지 않음)
git commit --no-verify -m "emergency fix"

# 또는 환경변수 사용
SKIP=terraform_tfsec git commit -m "skip tfsec"
```

## 📚 추가 리소스

- [Pre-commit 공식 문서](https://pre-commit.com/)
- [Pre-commit Terraform](https://github.com/antonbabenko/pre-commit-terraform)
- [TFLint](https://github.com/terraform-linters/tflint)
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [terraform-docs](https://terraform-docs.io/)

## 🤝 기여하기

Pre-commit 설정을 개선하고 싶다면:

1. `.pre-commit-config.yaml` 수정
2. `pre-commit run --all-files`로 테스트
3. PR 생성

---

**문의사항이 있으시면 팀 리드에게 연락하세요.**
