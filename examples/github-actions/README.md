# GitHub Actions 워크플로우 예제

애플리케이션 레포지토리에서 사용할 GitHub Actions 워크플로우 예제입니다.

## 파일

- `deploy-backend.yml`: Backend 애플리케이션 배포 워크플로우
- `deploy-frontend.yml`: Frontend 애플리케이션 배포 워크플로우

## 사용 방법

### 1. 워크플로우 파일 복사

애플리케이션 레포지토리에 `.github/workflows/` 디렉토리를 생성하고 해당 파일을 복사합니다.

**Backend 레포:**
```bash
mkdir -p .github/workflows
cp examples/github-actions/deploy-backend.yml .github/workflows/deploy.yml
```

**Frontend 레포:**
```bash
mkdir -p .github/workflows
cp examples/github-actions/deploy-frontend.yml .github/workflows/deploy.yml
```

### 2. GitHub Secrets 설정

Repository Settings > Secrets and variables > Actions에서 다음 Secrets를 추가:

| Secret 이름 | 값 |
|------------|-----|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key |

### 3. Task Definition 파일 준비

레포지토리 루트에 `task-definition.json` 파일을 추가합니다.

자세한 내용은 [ECS-DEPLOYMENT-GUIDE.md](../../ECS-DEPLOYMENT-GUIDE.md)를 참고하세요.

### 4. 배포

`main` 브랜치에 푸시하면 자동으로 배포됩니다:

```bash
git add .
git commit -m "feat: Add new feature"
git push origin main
```

## 워크플로우 동작

1. **Checkout**: 코드 체크아웃
2. **AWS 인증**: AWS credentials 설정
3. **ECR 로그인**: Docker가 ECR에 접근할 수 있도록 인증
4. **이미지 빌드**: Dockerfile로 이미지 빌드
5. **이미지 푸시**: ECR에 이미지 업로드 (Git SHA + latest 태그)
6. **Task Definition 업데이트**: 새 이미지로 Task Definition 생성
7. **ECS 배포**: 새 Task Definition으로 Service 업데이트
8. **안정화 대기**: 모든 태스크가 정상 상태가 될 때까지 대기

## 커스터마이징

### 환경별 배포

```yaml
on:
  push:
    branches:
      - main          # Production
      - staging       # Staging
      - develop       # Development

env:
  ECS_SERVICE: ${{ github.ref == 'refs/heads/main' && 'cat-backend-service' || 'cat-backend-service-staging' }}
```

### 수동 배포

워크플로우에서 `workflow_dispatch`가 이미 활성화되어 있습니다.

GitHub Actions 탭에서 "Run workflow" 버튼을 클릭하여 수동 배포 가능합니다.

### 빌드 캐싱

Docker 빌드 속도를 높이려면 캐싱을 추가:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

## 참고

자세한 내용은 [ECS-DEPLOYMENT-GUIDE.md](../../ECS-DEPLOYMENT-GUIDE.md)를 참고하세요.
