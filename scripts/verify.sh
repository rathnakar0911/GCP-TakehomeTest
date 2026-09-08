#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
PRIMARY="gke_${PROJECT_ID}_us-central1_gke-primary"
SECONDARY="gke_${PROJECT_ID}_us-east1_gke-secondary"

echo '--- Cluster health ---'
gcloud container clusters list --project "$PROJECT_ID"

echo '--- Workloads ---'
kubectl --context "$PRIMARY" -n demo get pods,svc,hpa
kubectl --context "$SECONDARY" -n demo get pods,svc,hpa

echo '--- Fleet ---'
gcloud container fleet memberships list --project "$PROJECT_ID"

echo '--- Multi-cluster services ---'
kubectl --context "$PRIMARY" -n demo get serviceimports.net.gke.io || true

echo '--- Gateway ---'
kubectl --context "$PRIMARY" -n demo get gateway,httproute
kubectl --context "$PRIMARY" -n demo describe gateway global-external-gateway || true

echo '--- Grafana ---'
kubectl --context "$PRIMARY" -n observability get pods,svc

echo '--- Logs ---'
gcloud logging read 'resource.type="k8s_container" AND resource.labels.namespace_name="demo"' --project "$PROJECT_ID" --limit 10 --format='table(timestamp,severity,resource.labels.cluster_name,resource.labels.pod_name,textPayload)'
