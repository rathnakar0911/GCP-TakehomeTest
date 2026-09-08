GCP GKE Multi-Cluster Observability Assessment

This repository implements the assessment assignment as a reproducible, low-cost assessment environment:

- Two GKE Standard clusters in different regions.
- One shared VPC with dedicated subnets and secondary Pod/Service ranges.
- Workload Identity enabled on both clusters.
- Two stateless applications, deployed with multiple replicas to both clusters.
- ConfigMaps, Kubernetes Secrets, rolling updates, PodDisruptionBudgets and HPAs.
- GKE Multi-cluster Gateway + Multi-cluster Services, providing one global external Application Load Balancer IP.
- Cloud Logging workload logs exported to BigQuery.
- Grafana hosted on GKE, querying BigQuery for log analysis and Google Cloud Monitoring for Kubernetes/load-balancer metrics.
- Four required Grafana panels: application errors, pod restarts, latency percentiles, CPU/memory utilization.
- BigQuery sample queries and a troubleshooting scenario.

Important cost note: GKE, external load balancing, Artifact Registry, BigQuery queries/storage and other services can incur charges. The assignment explicitly allows skipping features unavailable in a GCP free-tier environment. This implementation deliberately keeps node counts and VM sizes small, but you should destroy the environment after evaluation.

Architecture

flowchart TB
    U[Internet users] --> GLB[Global external Application Load Balancer\nGKE Multi-cluster Gateway]
    GLB --> C1[GKE Primary\nus-central1]
    GLB --> C2[GKE Secondary\nus-east1]
    C1 --> A1[App A\n2+ Pods + HPA]
    C1 --> B1[App B\n2+ Pods + HPA]
    C2 --> A2[App A\n2+ Pods + HPA]
    C2 --> B2[App B\n2+ Pods + HPA]
    A1 --> L[Cloud Logging]
    B1 --> L
    A2 --> L
    B2 --> L
    L --> BQ[BigQuery log sink]
    L --> MON[Cloud Monitoring]
    BQ --> G[Grafana]
    MON --> G

The current GKE documentation recommends multi-cluster Gateway as the newer multi-cluster traffic API. It uses a fleet, a config cluster, ServiceExport/ServiceImport, a Gateway, and an HTTPRoute; the global GatewayClass creates a global external Application Load Balancer. 

Repository layout


gcp-gke-observability/
├── README.txt
├── terraform/
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── apis.tf
│   ├── network.tf
│   ├── gke.tf
│   ├── artifact.tf
│   ├── bigquery.tf
│   ├── grafana_sa.tf
│   └── terraform.tfvars.example
├── apps/
│   ├── app-a/                  # Spring Boot 3 / Java 17
│   └── app-b/                  # FastAPI / Python
├── kubernetes/
│   ├── apps/
│   │   ├── namespace.yaml
│   │   ├── app-a.yaml
│   │   └── app-b.yaml
│   ├── observability/
│   │   └── gateway.yaml
│   ├── grafana-config.yaml
│   └── grafana/
│       └── dashboard.json
├── bigquery/
│   └── queries.sql
├── docs/
│   ├── architecture.txt
│   ├── design-decisions.txt
│   ├── troubleshooting.txt
└── scripts/
    ├── deploy.sh
    ├── verify.sh
    ├── load-test.sh
    └── cleanup.sh


Deploy everything


chmod +x scripts/*.sh
export PROJECT_ID="YOUR_PROJECT_ID"
./scripts/deploy.sh

The script:

1. Enables required Google APIs.
2. Creates the VPC/subnets/NAT.
3. Creates two GKE Standard clusters.
4. Registers them with the fleet.
5. Enables multi-cluster Services and multi-cluster Gateway.
6. Builds/pushes both application images.
7. Deploys both applications to both clusters.
8. Creates ServiceExport resources.
9. Creates the global external Gateway and HTTPRoute.
10. Creates the BigQuery log sink.
11. Creates a read-only Grafana service account.
12. Deploys Grafana and provisions the BigQuery + Cloud Monitoring data sources.

Verify


./scripts/verify.sh

Observability implementation

Cloud Logging

GKE workload logging is enabled at the cluster level. Application containers write request/error events to stdout/stderr, which Cloud Logging collects. The Terraform log sink filters workload logs from the demo namespace and routes them to the gke_logs BigQuery dataset.

Google Cloud's current logging documentation notes that a traditional BigQuery log sink creates tables based on log names and can use partitioned tables. 

BigQuery

The bigquery/queries.sql file contains examples for:

- errors over time
- errors by application
- errors by cluster
- application latency percentiles

The exact generated table/schema should be checked in BigQuery after the first logs arrive. GKE/Cloud Logging schemas can expose structured JSON as jsonPayload; if the generated table keeps the application event as textPayload, use the text variant included in the query comments.

Grafana

Grafana is hosted inside the primary GKE cluster and exposed through a Kubernetes LoadBalancer Service. It has:

- BigQuery data source for log analysis.
- Google Cloud Monitoring data source for Kubernetes and load-balancer metrics.

The current Grafana BigQuery plugin supports SQL queries, time-series macros such as $__timeFilter, and BigQuery-backed dashboards. The Google Cloud Monitoring data source is also built into current Grafana distributions. 

Required dashboard panels

1. Application error events / minute — BigQuery.
2. Pod restart counts by namespace — Cloud Monitoring kubernetes.io/container/restart_count.
3. Request latency p50/p95/p99 — Cloud Monitoring external Application Load Balancer latency distribution.
4. Container CPU/memory utilization — Cloud Monitoring GKE container metrics.

GKE currently exposes kubernetes.io/container/restart_count, while container CPU/memory metrics are available through Cloud Monitoring. External Application Load Balancer metrics include total latency distributions suitable for percentile charts. 

Architecture and design decisions

See:

- docs/architecture.txt
- docs/design-decisions.txt

Troubleshooting evidence

See docs/troubleshooting.txt for the issue observed during this deployment and its resolution.

Security notes

We demonstrate:

- Workload Identity on GKE.
- Dedicated node service account with logging/monitoring roles.
- Least-privilege read-only Grafana service account for BigQuery/Monitoring.
- Kubernetes Secrets for application configuration.
- No credentials committed to Git.
- Runtime Grafana credentials generated under .runtime/.

For production, move application secrets to Secret Manager + the GKE Secret Manager CSI integration, avoid service-account key files, use private clusters where appropriate, add Cloud Armor/WAF policies, and use Binary Authorization/attestation.

Unable to Cover as part of free / low cost billing : 

- Cloud Armor WAF policy.
- Private Service Access for enterprise-managed Google APIs.
- Anthos/Cloud Service Mesh mTLS and traffic shaping.
- Binary Authorization.
- Cloud SQL HA / cross-region state replication.
- Memorystore cross-region replication.
- Cloud Profiler.
- Cloud Trace distributed tracing.
- Enterprise SIEM integration.
- Cloud DNS, because a real domain name is not supplied. The working endpoint is the global Gateway IP; DNS can be added later with a domain you control.

Cleanup


./scripts/cleanup.sh

Do not commit .runtime/ or any locally-created credentials.
