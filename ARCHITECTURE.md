# Infrastructure Architecture

Terraform으로 구성된 Cat CICD AWS 인프라 아키텍처입니다.

## 전체 인프라 구조

```mermaid
graph TB
    subgraph Internet
        User[사용자]
        GitHub[GitHub Actions]
    end

    subgraph AWS["AWS Cloud (ap-northeast-2)"]
        subgraph VPC["VPC (10.180.0.0/20)"]
            IGW[Internet Gateway]
            NAT[NAT Gateway]

            subgraph PublicSubnet["Public Subnets (2 AZs)"]
                ALB[Application Load Balancer]
            end

            subgraph PrivateAppSubnet["Private App Subnets (2 AZs)"]
                ECS[ECS Fargate Cluster]
                Task1[Gateway API Task]
                Task2[Reservation API Task]
                Task3[Inventory API Task]
                Task4[Payment Sim API Task]
                Task5[Reservation Worker Task]
            end

            subgraph PrivateDBSubnet["Private DB Subnets (2 AZs)"]
                DB[(Future: RDS/Database)]
            end
        end

        ECR[ECR Repositories]
        CW[CloudWatch Logs]
        S3[S3 Backend<br/>tfstate 저장]
        DDB[DynamoDB<br/>State Lock]
    end

    User -->|HTTPS/HTTP| ALB
    ALB -->|Health Check| Task1
    ALB -->|Route| Task2
    ALB -->|Route| Task3
    ALB -->|Route| Task4

    ECS -.->|실행| Task1
    ECS -.->|실행| Task2
    ECS -.->|실행| Task3
    ECS -.->|실행| Task4
    ECS -.->|실행| Task5

    Task1 -->|Pull Image| ECR
    Task2 -->|Pull Image| ECR
    Task3 -->|Pull Image| ECR
    Task4 -->|Pull Image| ECR
    Task5 -->|Pull Image| ECR

    Task1 -->|Logs| CW
    Task2 -->|Logs| CW
    Task3 -->|Logs| CW
    Task4 -->|Logs| CW
    Task5 -->|Logs| CW

    PrivateAppSubnet -->|Outbound| NAT
    NAT --> IGW
    IGW --> Internet

    GitHub -->|terraform apply| S3
    GitHub -->|State Lock| DDB

    style ALB fill:#ff9900
    style ECS fill:#ff9900
    style ECR fill:#ff9900
    style VPC fill:#e8f4f8
    style PublicSubnet fill:#b3d9ff
    style PrivateAppSubnet fill:#ffe6cc
    style PrivateDBSubnet fill:#f0e6ff
```

## 네트워크 구조

```mermaid
graph LR
    subgraph VPC["VPC: 10.180.0.0/20"]
        subgraph AZ1["ap-northeast-2a"]
            PubA[Public Subnet<br/>10.180.0.0/24]
            AppA[Private App Subnet<br/>10.180.4.0/22]
            DBA[Private DB Subnet<br/>10.180.2.0/24]
        end

        subgraph AZ2["ap-northeast-2c"]
            PubC[Public Subnet<br/>10.180.1.0/24]
            AppC[Private App Subnet<br/>10.180.8.0/22]
            DBC[Private DB Subnet<br/>10.180.3.0/24]
        end

        IGW[Internet Gateway]
        NAT[NAT Gateway]
    end

    Internet --> IGW
    IGW --> PubA
    IGW --> PubC
    PubA --> NAT
    NAT --> AppA
    NAT --> AppC

    style AZ1 fill:#e8f4f8
    style AZ2 fill:#e8f4f8
    style PubA fill:#b3d9ff
    style PubC fill:#b3d9ff
    style AppA fill:#ffe6cc
    style AppC fill:#ffe6cc
    style DBA fill:#f0e6ff
    style DBC fill:#f0e6ff
```

## Terraform 모듈 의존성

```mermaid
graph TD
    Main[main.tf]

    VPC[VPC Module]
    SG[Security Groups Module]
    ALB[ALB Module]
    ECS[ECS Module]
    ECR[ECR Module]

    Main --> VPC
    Main --> SG
    Main --> ALB
    Main --> ECS
    Main --> ECR

    SG -.->|vpc_id| VPC
    ALB -.->|vpc_id, subnets| VPC
    ALB -.->|security_group| SG

    style Main fill:#4CAF50
    style VPC fill:#2196F3
    style SG fill:#FF9800
    style ALB fill:#F44336
    style ECS fill:#9C27B0
    style ECR fill:#00BCD4
```

## 배포 워크플로우

```mermaid
sequenceDiagram
    participant Dev as 개발자
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant AWS as AWS
    participant S3 as S3 Backend

    Dev->>GH: git push (main)
    GH->>GHA: Trigger Workflow

    GHA->>GHA: Terraform fmt check
    GHA->>GHA: Terraform validate

    GHA->>S3: terraform init (backend)
    GHA->>AWS: terraform plan

    alt Production Environment
        GHA-->>Dev: Require Approval
        Dev->>GHA: Approve
    end

    GHA->>AWS: terraform apply
    AWS-->>GHA: Infrastructure Created
    GHA->>GH: Update Summary

    Note over GHA,AWS: VPC, ECS, ALB, ECR 생성
```

## 보안 그룹 규칙

```mermaid
graph LR
    Internet[Internet] -->|80, 443| ALBSG[ALB Security Group]
    ALBSG -->|동적 포트<br/>8080-8090| ECSSG[ECS Tasks SG]
    ECSSG -->|3306| RDSSG[RDS SG<br/>Optional]

    style ALBSG fill:#ff9900
    style ECSSG fill:#ff9900
    style RDSSG fill:#336699
```

## 주요 컴포넌트

### 1. VPC (Virtual Private Cloud)
- **CIDR**: 10.180.0.0/20
- **AZ**: ap-northeast-2a, ap-northeast-2c (2개)
- **Public Subnets**: ALB 배치
- **Private App Subnets**: ECS Tasks 배치
- **Private DB Subnets**: 향후 RDS 배치

### 2. ECS (Elastic Container Service)
- **Cluster**: cat-cluster
- **Launch Type**: Fargate
- **Container Insights**: 활성화 가능
- **Microservices**:
  - Gateway API
  - Reservation API
  - Inventory API
  - Payment Simulation API
  - Reservation Worker

### 3. ECR (Elastic Container Registry)
- 각 마이크로서비스별 독립 리포지토리
- Lifecycle Policy: 10개 이미지 보관

### 4. ALB (Application Load Balancer)
- HTTP/HTTPS 리스너
- Health Check: `/health`
- ACM 인증서 지원 (*.go-to-learn.net)

### 5. Security Groups
- ALB SG: 80, 443 포트 오픈
- ECS Tasks SG: ALB에서의 트래픽만 허용
- RDS SG (Optional): ECS Tasks에서만 접근

### 6. IAM Roles
- **Task Execution Role**: ECR 이미지 pull, CloudWatch 로그
- **Task Role**: 애플리케이션별 AWS 서비스 접근

## 비용 예상 (월별)

| 리소스 | 사양 | 예상 비용 |
|--------|------|----------|
| NAT Gateway | 1개 | $32.85 |
| ALB | 1개 | $22.56 |
| VPC 기타 | - | $8.08 |
| ECS Fargate | Task 없음 | $0 |
| ECR | 이미지 없음 | ~$0 |
| S3 (tfstate) | - | ~$0.02 |
| DynamoDB | - | $0 |
| **합계** | - | **~$63.49/월** |

*실제 ECS Task 실행 시 vCPU, 메모리 사용량에 따라 추가 비용 발생*

## 참고사항

- CloudFront 모듈은 준비되어 있으나 현재 main.tf에서 비활성화 상태
- RDS 보안 그룹은 준비되어 있으나 실제 RDS 리소스는 미생성
- GitHub Actions를 통한 자동 배포 구성 완료
- Pre-commit hooks로 코드 품질 관리
