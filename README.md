# compose

운영 환경과 유사한 로컬 인프라를 빠르게 구성하기 위한 Docker Compose 모음입니다.
각 디렉터리는 독립 실행이 가능하며, 공용 Docker 외부 네트워크를 통해 서로 통신합니다.

## 구성 스택

| 디렉터리 | 구성 | 용도 |
|---|---|---|
| `postgres/` | PostgreSQL Primary/Replica + 확장 | 관계형 DB, 복제 테스트 |
| `redis/` | Redis 3노드 클러스터 | 캐시/세션, 클러스터 테스트 |
| `kafka/` | Kafka KRaft 3브로커 + Kafka UI | 이벤트 스트리밍 |
| `otel/` | OTel Collector + OpenSearch + Data Prepper + Prometheus + Alertmanager + Pyroscope | 관측성(Trace/Log/Metric/Profile) |

## 사전 요구 사항

- Docker Engine / Docker Compose v2
- OpenSearch 실행을 위한 커널 설정

```bash
sudo sysctl -w vm.max_map_count=262144
```

## 빠른 시작

### 1) 공용 네트워크 생성 (최초 1회)

```bash
docker network create <shared_network_name>
```

> 기본 네트워크 이름은 각 compose 파일에서 확인/변경 가능합니다.

### 2) `.env` 파일 생성

`.env`는 git에서 제외됩니다. 각 디렉터리에서 `.env.example`을 복사해 `.env`를 생성하세요.

```bash
cp postgres/.env.example postgres/.env
cp redis/.env.example redis/.env
cp kafka/.env.example kafka/.env
cp otel/.env.example otel/.env
```

### 3) 스택 기동

```bash
cd postgres && docker compose up -d
cd ../redis && docker compose up -d
cd ../kafka && docker compose up -d
cd ../otel && docker compose up -d
```

---

## 환경변수 템플릿

아래 예시는 형태만 제공합니다. 실제 값은 팀 정책에 맞게 입력하세요.

### `postgres/.env`

```env
POSTGRES_USER=<postgres_user>
POSTGRES_PASSWORD=<postgres_password>
POSTGRES_DB=<postgres_database>
REPLICATION_USER=<replication_user>
REPLICATION_PASSWORD=<replication_password>
```

### `redis/.env`

```env
REDIS_PASSWORD=<redis_password>
```

### `kafka/.env`

```env
CLUSTER_ID=<kafka_kraft_cluster_id>
KAFKA_CLUSTERS_0_NAME=<kafka_ui_cluster_display_name>
KAFKA_CLIENT_USERNAME=<kafka_client_username>
KAFKA_CLIENT_PASSWORD=<kafka_client_password>
```

### `otel/.env`

```env
OPENSEARCH_PASSWORD=<opensearch_admin_password>
OTEL_CLUSTER_NAME=<opensearch_cluster_name>
OPENSEARCH_DASHBOARDS_USERNAME=<dashboards_system_username>
OPENSEARCH_DASHBOARDS_PASSWORD=<dashboards_system_password>
POSTGRES_USER=<postgres_user>
POSTGRES_PASSWORD=<postgres_password>
POSTGRES_DB=<postgres_database>
REDIS_PASSWORD=<redis_password>
```

---

## postgres

PostgreSQL Primary/Replica 구성으로 스트리밍 복제를 테스트할 수 있습니다.

### 서비스/포트

| 컨테이너 | 호스트 포트 | 비고 |
|---|---|---|
| `postgres-primary` | `<postgres_primary_port>` | 읽기/쓰기 |
| `postgres-replica` | `<postgres_replica_port>` | 읽기 전용 |

### 주요 특징

- `env_file`로 자격정보 주입
- `replica-entrypoint.sh`에서 `pg_basebackup` 기반 초기 동기화
- `init/00-replication.sh`로 replication user/slot 생성
- `init/01-extensions.sql`로 확장 자동 설치

### 포함 확장

- `pg_trgm`
- `postgis`, `postgis_topology`
- `pgaudit`
- `pg_stat_statements`
- `vector`

### 접속 URI 형태

- Primary: `postgresql://<user>:<password>@<host>:<port>/<database>`
- Replica: `postgresql://<user>:<password>@<host>:<port>/<database>`

---

## redis

Redis 3노드 클러스터 구성입니다.

### 서비스/포트

| 컨테이너 | 호스트 포트 | 비고 |
|---|---|---|
| `redis-node-1` | `<redis_node1_port>` | 클러스터 노드 |
| `redis-node-2` | `<redis_node2_port>` | 클러스터 노드 |
| `redis-node-3` | `<redis_node3_port>` | 클러스터 노드 |
| `redis-cluster-init` | - | 1회성 클러스터 부트스트랩 |

### 주요 특징

- 인증은 `--requirepass`, `--masterauth`로 `.env`에서 주입
- `redis.conf`는 성능/영속성/클러스터 설정 중심
- `redis-cluster-init`가 상태 확인 후 필요 시에만 `--cluster create` 실행

### 접속 URI 형태

- 단일 노드: `redis://:<password>@<host>:<port>`
- 클러스터 클라이언트: `redis://:<password>@<host1>:<port1>,<host2>:<port2>,<host3>:<port3>`

---

## kafka

Kafka KRaft 3브로커 구성입니다 (ZooKeeper 없음).

### Listener 구조

| 리스너 | 용도 | 보안 |
|---|---|---|
| `PLAINTEXT` | 브로커 내부 통신 | `PLAINTEXT` |
| `CONTROLLER` | KRaft 컨트롤러 통신 | `PLAINTEXT` |
| `EXTERNAL` | 호스트/외부 클라이언트 접속 | `SASL_PLAINTEXT` + `PLAIN` |

### 서비스/포트

| 컨테이너 | 외부 접속 주소 형태 |
|---|---|
| `kafka-1` | `<host>:<kafka_broker1_external_port>` |
| `kafka-2` | `<host>:<kafka_broker2_external_port>` |
| `kafka-3` | `<host>:<kafka_broker3_external_port>` |
| `kafka-ui` | `http://<host>:<kafka_ui_port>` |

### 클라이언트 설정 형태

```properties
bootstrap.servers=<host>:<port>,<host>:<port>,<host>:<port>
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<username>" password="<password>";
```

`CLUSTER_ID`는 KRaft 내부 식별자이고, `KAFKA_CLUSTERS_0_NAME`은 Kafka UI 표시명입니다.

---

## otel

애플리케이션은 OTLP로만 전송하고, Collector가 신호별 저장소로 라우팅합니다.

```text
Application (OTLP gRPC/HTTP)
  -> OTel Collector
     -> Traces   -> Data Prepper -> OpenSearch
     -> Logs     -> OpenSearch
     -> Metrics  -> Prometheus
     -> Profiles -> Pyroscope
```

### AWS 대응 개념

| 로컬 구성 | AWS 대응 서비스 |
|---|---|
| OpenSearch | Amazon OpenSearch Service |
| OpenSearch Dashboards | OpenSearch Dashboards |
| Data Prepper | Amazon OpenSearch Ingestion |
| Prometheus | Amazon Managed Prometheus |
| OTel Collector | ADOT |
| Pyroscope | Pyroscope (self-managed) |

### 서비스 목록

| 서비스 | 이미지 | 포트 |
|---|---|---|
| `opensearch` | `opensearch-nori:<version>` | `<opensearch_http_port>`, `<opensearch_transport_port>` |
| `opensearch-dashboards` | `opensearchproject/opensearch-dashboards:<version>` | `<dashboards_port>` |
| `otel-collector` | `otel/opentelemetry-collector-contrib:<version>` | `<otlp_grpc_port>`, `<otlp_http_port>`, `<collector_metrics_port>` |
| `data-prepper` | `opensearchproject/data-prepper:<version>` | `<data_prepper_otel_trace_port>`, `<data_prepper_health_port>` |
| `prometheus` | `prom/prometheus:<version>` | `<prometheus_port>` |
| `alertmanager` | `prom/alertmanager:<version>` | `<alertmanager_port>` |
| `pyroscope` | `grafana/pyroscope:<version>` | `<pyroscope_port>` |
| `postgres-exporter` | `prometheuscommunity/postgres-exporter:<version>` | `<postgres_exporter_port>` |
| `redis-exporter` | `oliver006/redis_exporter:<version>` | `<redis_exporter_port>` |

### 설정 파일

| 파일 | 설명 |
|---|---|
| `otel/docker-compose.yaml` | OTel 스택 오케스트레이션 |
| `otel/Dockerfile` | OpenSearch 커스텀 이미지 빌드 |
| `otel/otel-collector.yaml` | Collector 파이프라인 (수집/처리/내보내기) |
| `otel/data-prepper-pipelines.yaml` | Trace 파이프라인 정의 |
| `otel/data-prepper-config.yaml` | Data Prepper 런타임 설정 |
| `otel/data-prepper-entrypoint.sh` | Data Prepper 템플릿 변수 치환 |
| `otel/opensearch_dashboards.yml` | Dashboards 설정 |
| `otel/prometheus.yml` | Prometheus scrape/alert 설정 |
| `otel/alertmanager.yml` | Alertmanager 라우팅 설정 |
| `otel/rules/alerts.yml` | 알림 규칙 |

### 서비스 엔드포인트 형태

| 서비스 | URI 형태 |
|---|---|
| OpenSearch Dashboards | `http://<host>:<dashboards_port>` |
| OpenSearch | `http://<host>:<opensearch_port>` |
| Prometheus | `http://<host>:<prometheus_port>` |
| Alertmanager | `http://<host>:<alertmanager_port>` |
| Pyroscope | `http://<host>:<pyroscope_port>` |
| OTel Collector gRPC | `<host>:<otlp_grpc_port>` |
| OTel Collector HTTP | `http://<host>:<otlp_http_port>` |
| OTel Collector Metrics | `http://<host>:<collector_metrics_port>` |

### 애플리케이션 OTel 설정 형태

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=<otlp_endpoint_uri>
export OTEL_EXPORTER_OTLP_PROTOCOL=<grpc_or_http/protobuf>
export OTEL_RESOURCE_ATTRIBUTES="service.name=<service_name>,deployment.environment=<environment>"
```

### 초기 설정 절차 (중요, 순서 권장)

1. `otel` 스택 기동 후 OpenSearch health 확인
2. 서비스맵 인덱스 템플릿 생성
3. 애플리케이션 트래픽 발생
4. Dashboards Workspace/Data Source/Dataset 연결

#### 서비스맵 템플릿 생성 예시 (형태)

```bash
curl -s -u '<opensearch_admin_user>:<opensearch_admin_password>' \
  -X PUT 'http://<host>:<opensearch_port>/_index_template/otel-v2-apm-service-map-template' \
  -H 'Content-Type: application/json' \
  -d '{
  "index_patterns": ["otel-v2-apm-service-map*"],
  "priority": <priority_number>,
  "template": {
    "mappings": {
      "properties": {
        "sourceNode": { "properties": { "type": { "type": "keyword" }, "keyAttributes": { "properties": { "name": { "type": "keyword" }, "environment": { "type": "keyword" } } }, "groupByAttributes": { "type": "object" } } },
        "targetNode": { "properties": { "type": { "type": "keyword" }, "keyAttributes": { "properties": { "name": { "type": "keyword" }, "environment": { "type": "keyword" } } }, "groupByAttributes": { "type": "object" } } },
        "sourceOperation": { "properties": { "name": { "type": "keyword" }, "attributes": { "type": "object" } } },
        "targetOperation": { "properties": { "name": { "type": "keyword" }, "attributes": { "type": "object" } } },
        "nodeConnectionHash": { "type": "keyword" },
        "operationConnectionHash": { "type": "keyword" },
        "timestamp": { "type": "date" }
      }
    }
  }
}'
```

> 단일 서비스 환경에서는 이 템플릿이 없으면 서비스맵에서 `targetNode` 관련 오류가 발생할 수 있습니다.

### Dashboards 설정 절차

1. `http://<host>:<dashboards_port>` 접속 후 로그인
2. Workspace 생성
3. Dashboards Management에서 Data Source 생성
4. Workspace에 Data Source 연결
5. Discover에서 Logs/Traces Dataset 생성

Data Source 등록 시 값 형태:

- Title: `<data_source_name>`
- Endpoint URL: `http://<opensearch_container_name>:<opensearch_http_port>`
- Authentication: Username/Password

Traces Dataset 생성 시:

- Index: `<traces_index_pattern>`
- Time field: `startTime` (일부 환경에서 `@timestamp` 이슈 회피)

Logs Dataset 생성 시:

- Index: `<logs_index_pattern>`
- Time field: `@timestamp` 또는 `observedTimestamp`

### 데이터 유입 확인

```bash
# Collector 수신/송신 확인
curl -s http://<host>:<collector_metrics_port>/metrics | rg 'receiver_accepted|exporter_sent'

# OpenSearch 인덱스 생성 확인
curl -s -u '<opensearch_admin_user>:<opensearch_admin_password>' \
  'http://<host>:<opensearch_port>/_cat/indices?v'
```

예상 인덱스 형태:

- `ss4o_logs-*`
- `otel-v1-apm-span-*`
- `otel-v2-apm-service-map*`

### Alerting

- 규칙 파일: `otel/rules/alerts.yml`
- 라우팅 파일: `otel/alertmanager.yml`
- `receivers.default.webhook_configs.url`을 실제 webhook URI로 교체 후 사용

Webhook URI 형태 예시:

- `https://<webhook_host>/<path>`

### 알려진 제약/이슈

| 항목 | 영향 | 우회/대응 |
|---|---|---|
| `@timestamp`가 기대와 다르게 저장됨 | Traces 조회 시 시간축 문제 가능 | Traces Dataset의 time field를 `startTime`으로 지정 |
| `durationInNanos` 스키마 불일치 | 일부 Trace 패널 에러 가능 | Spans/기본 조회 중심으로 확인 |
| `targetNode.keyAttributes` 누락 | 서비스맵 패널 오류 가능 | 서비스맵 인덱스 템플릿 선생성 |
| Metrics UI 제약 | Dashboards 내 Metrics 연동 제한 | Prometheus UI 직접 조회 |
| HTTP 비TLS | 로컬 개발 외 환경에 부적합 | 운영에서는 HTTPS/TLS 적용 |

### 참고

- OpenSearch 커스텀 빌드에 `analysis-nori`, `analysis-icu` 플러그인 포함
- Data Prepper는 파이프라인 템플릿에 대해 entrypoint에서 환경변수 치환 수행
- Profiles는 Collector feature gate(`service.profilesSupport`) 활성 시 사용

---

## 트러블슈팅

- `network ... not found`
  - 공용 외부 네트워크를 먼저 생성했는지 확인
- OpenSearch 부팅 실패
  - `vm.max_map_count` 값 확인
- Redis 클러스터 미구성
  - `redis-cluster-init` 로그 확인 (`cluster_state:ok` 여부)
- Postgres replica 미기동
  - primary health 상태/복제 계정 설정/데이터 볼륨 초기화 여부 확인
- Kafka 외부 접속 실패
  - `EXTERNAL` 포트, `SASL_PLAINTEXT` 설정, username/password 일치 여부 확인
- OTel 데이터가 UI에 안 보임
  - Collector metrics 증가 여부
  - OpenSearch 인덱스 생성 여부
  - Dashboards Data Source/Dataset/time field 설정 확인

---

## 운영 명령

### 스택 정지

```bash
cd <stack_directory>
docker compose down
```

### 데이터 볼륨까지 초기화

```bash
cd <stack_directory>
docker compose down -v
```

### 전체 정리

```bash
docker network rm <shared_network_name>
```

