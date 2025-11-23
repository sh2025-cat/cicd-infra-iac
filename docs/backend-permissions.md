# Backend ECS Task Role 권한

Backend 컨테이너가 사용할 수 있는 AWS 권한 목록입니다.

## Role 정보

- **Role Name**: `cat-cluster-task-role`
- **Role ARN**: `arn:aws:iam::277679348386:role/cat-cluster-task-role`

---

## 권한 목록

### S3 (저장소)

| Action | 설명 |
|--------|------|
| `s3:GetObject` | S3 객체 읽기 |
| `s3:PutObject` | S3 객체 쓰기 |

### DynamoDB (NoSQL DB)

| Action | 설명 |
|--------|------|
| `dynamodb:GetItem` | 단일 항목 조회 |
| `dynamodb:PutItem` | 항목 생성/수정 |
| `dynamodb:Query` | 쿼리 실행 |
| `dynamodb:Scan` | 테이블 전체 스캔 |

### SQS (메시지 큐)

| Action | 설명 |
|--------|------|
| `sqs:SendMessage` | 메시지 전송 |
| `sqs:ReceiveMessage` | 메시지 수신 |
| `sqs:DeleteMessage` | 메시지 삭제 |

### Secrets Manager (비밀 관리)

| Action | 설명 |
|--------|------|
| `secretsmanager:GetSecretValue` | 비밀 값 조회 |

### Tagging API (태그 조회)

| Action | 설명 |
|--------|------|
| `tag:GetResources` | 태그된 리소스 조회 |
| `tag:GetTagKeys` | 태그 키 목록 조회 |
| `tag:GetTagValues` | 태그 값 목록 조회 |

### CloudWatch (모니터링)

| Action | 설명 |
|--------|------|
| `cloudwatch:GetMetricData` | 메트릭 데이터 조회 |
| `cloudwatch:GetMetricStatistics` | 메트릭 통계 조회 |
| `cloudwatch:ListMetrics` | 메트릭 목록 조회 |
| `cloudwatch:DescribeAlarms` | 알람 정보 조회 |

### CloudWatch Logs (로그)

| Action | 설명 |
|--------|------|
| `logs:GetLogEvents` | 로그 이벤트 조회 |
| `logs:DescribeLogStreams` | 로그 스트림 목록 조회 |
| `logs:DescribeLogGroups` | 로그 그룹 목록 조회 |
| `logs:FilterLogEvents` | 로그 필터링 조회 |

### ECS - 조회 (AllowECSDescribe)

| Action | 설명 |
|--------|------|
| `ecs:DescribeServices` | 서비스 정보 조회 |
| `ecs:DescribeTasks` | 태스크 정보 조회 |
| `ecs:DescribeTaskDefinition` | 태스크 정의 조회 |
| `ecs:ListTasks` | 태스크 목록 조회 |

### ECS - Task 관리 (AllowECSTaskManagement)

| Action | 설명 |
|--------|------|
| `ecs:RunTask` | 태스크 실행 |
| `ecs:StopTask` | 태스크 중지 |
| `ecs:RegisterTaskDefinition` | 태스크 정의 등록 |
| `ecs:DeregisterTaskDefinition` | 태스크 정의 삭제 |

### ECS - Service 관리 (AllowECSServiceManagement)

| Action | 설명 |
|--------|------|
| `ecs:CreateService` | 서비스 생성 |
| `ecs:UpdateService` | 서비스 수정 |
| `ecs:DeleteService` | 서비스 삭제 |

### IAM (역할 전달)

| Action | 설명 |
|--------|------|
| `iam:PassRole` | 다른 서비스에 역할 전달 (ECS Task 실행 시 필요) |

---

## 리소스 범위

모든 권한은 `Resource = "*"`로 설정되어 있어 모든 리소스에 접근 가능합니다.

---

## 사용 예시

### ECS Task 실행

```javascript
const ecs = new AWS.ECS();

await ecs.runTask({
  cluster: 'cat-cluster',
  taskDefinition: 'cat-backend',
  launchType: 'FARGATE',
  networkConfiguration: {
    awsvpcConfiguration: {
      subnets: ['subnet-xxx'],
      securityGroups: ['sg-xxx']
    }
  }
}).promise();
```

### Secrets Manager에서 값 조회

```javascript
const secretsManager = new AWS.SecretsManager();

const secret = await secretsManager.getSecretValue({
  SecretId: 'cat-backend-env'
}).promise();

const values = JSON.parse(secret.SecretString);
```

### CloudWatch 메트릭 조회

```javascript
const cloudwatch = new AWS.CloudWatch();

const metrics = await cloudwatch.getMetricData({
  MetricDataQueries: [{
    Id: 'cpu',
    MetricStat: {
      Metric: {
        Namespace: 'AWS/ECS',
        MetricName: 'CPUUtilization',
        Dimensions: [{ Name: 'ClusterName', Value: 'cat-cluster' }]
      },
      Period: 300,
      Stat: 'Average'
    }
  }],
  StartTime: new Date(Date.now() - 3600000),
  EndTime: new Date()
}).promise();
```

---

## 관련 파일

- IAM 정책 정의: `modules/ecs/iam.tf`
- Task Definition: `test-deployments/backend-task-definition.json`
