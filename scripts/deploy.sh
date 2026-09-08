#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"
RUNTIME_DIR="$ROOT_DIR/.runtime"
mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
PRIMARY_CONTEXT="gke_${PROJECT_ID}_us-central1_gke-primary"
SECONDARY_CONTEXT="gke_${PROJECT_ID}_us-east1_gke-secondary"
REGISTRY="us-central1-docker.pkg.dev/${PROJECT_ID}/gke-assessment"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
  echo "Set PROJECT_ID or run: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

for cmd in gcloud terraform kubectl docker jq openssl; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd"; exit 1; }
done

gcloud config set project "$PROJECT_ID" >/dev/null

cat > "$TF_DIR/terraform.tfvars" <<VARS
project_id = "$PROJECT_ID"
VARS

pushd "$TF_DIR" >/dev/null
terraform init
terraform apply -auto-approve
popd >/dev/null

gcloud container clusters get-credentials gke-primary --region us-central1 --project "$PROJECT_ID"
gcloud container clusters get-credentials gke-secondary --region us-east1 --project "$PROJECT_ID"

# Enable Gateway API after cluster creation; this avoids a create-request incompatibility
# between the current Terraform provider and the GKE API.
gcloud container clusters update gke-primary --region us-central1 --gateway-api=standard --project "$PROJECT_ID" --quiet
gcloud container clusters update gke-secondary --region us-east1 --gateway-api=standard --project "$PROJECT_ID" --quiet

# Enable fleet features required by the multi-cluster Gateway.
gcloud container fleet multi-cluster-services enable --project "$PROJECT_ID" || true
# The MCS importer needs to discover VPC/network information.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[gke-mcs/gke-mcs-importer]" \
  --role="roles/compute.networkViewer" --quiet || true

gcloud container fleet ingress enable \
  --config-membership="projects/${PROJECT_ID}/locations/${PRIMARY_REGION:-us-central1}/memberships/gke-primary" \
  --project="$PROJECT_ID" || true

echo "Waiting for fleet ingress controller to become ready..."
sleep 30

# Build and push application images.
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

docker build --platform linux/amd64 -t "$REGISTRY/app-a:latest" "$ROOT_DIR/apps/app-a"
docker push "$REGISTRY/app-a:latest"
docker build --platform linux/amd64 -t "$REGISTRY/app-b:latest" "$ROOT_DIR/apps/app-b"
docker push "$REGISTRY/app-b:latest"

for pair in \
  "$PRIMARY_CONTEXT|primary" \
  "$SECONDARY_CONTEXT|secondary"; do
  IFS='|' read -r context cluster_name <<< "$pair"
  echo "Deploying applications to $cluster_name ($context)"
  kubectl --context "$context" apply -f "$ROOT_DIR/kubernetes/apps/namespace.yaml"
  sed -e "s#CLUSTER_NAME_PLACEHOLDER#$cluster_name#g" -e "s#IMAGE_REGISTRY_PLACEHOLDER#$REGISTRY#g" \
    "$ROOT_DIR/kubernetes/apps/app-a.yaml" | kubectl --context "$context" apply -f -
  sed -e "s#CLUSTER_NAME_PLACEHOLDER#$cluster_name#g" -e "s#IMAGE_REGISTRY_PLACEHOLDER#$REGISTRY#g" \
    "$ROOT_DIR/kubernetes/apps/app-b.yaml" | kubectl --context "$context" apply -f -
  kubectl --context "$context" -n demo rollout status deployment/app-a --timeout=5m
  kubectl --context "$context" -n demo rollout status deployment/app-b --timeout=5m
done

echo "Waiting for ServiceImports to propagate..."
for i in {1..30}; do
  if kubectl --context "$PRIMARY_CONTEXT" -n demo get serviceimports.net.gke.io app-a >/dev/null 2>&1 && \
     kubectl --context "$PRIMARY_CONTEXT" -n demo get serviceimports.net.gke.io app-b >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

kubectl --context "$PRIMARY_CONTEXT" apply -f "$ROOT_DIR/kubernetes/observability/gateway.yaml"

GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-$(openssl rand -hex 12)}"
printf '%s' "$GRAFANA_PASSWORD" > "$RUNTIME_DIR/grafana-password.txt"

sed "s/GCP_PROJECT_ID_PLACEHOLDER/$PROJECT_ID/g" "$ROOT_DIR/kubernetes/grafana-config.yaml" | kubectl --context "$PRIMARY_CONTEXT" apply -f -
kubectl --context "$PRIMARY_CONTEXT" -n observability create secret generic grafana-admin \
  --from-literal=password="$GRAFANA_PASSWORD" --dry-run=client -o yaml | kubectl --context "$PRIMARY_CONTEXT" apply -f -
kubectl --context "$PRIMARY_CONTEXT" -n observability create configmap grafana-env \
  --from-literal=GCP_PROJECT_ID="$PROJECT_ID" \
  --dry-run=client -o yaml | kubectl --context "$PRIMARY_CONTEXT" apply -f -
kubectl --context "$PRIMARY_CONTEXT" -n observability create configmap grafana-dashboard \
  --from-file=gke-assessment.json="$ROOT_DIR/kubernetes/grafana/dashboard.json" \
  --dry-run=client -o yaml | kubectl --context "$PRIMARY_CONTEXT" apply -f -

kubectl --context "$PRIMARY_CONTEXT" -n observability rollout status deployment/grafana --timeout=5m

VIP=""
for i in {1..60}; do
  VIP="$(kubectl --context "$PRIMARY_CONTEXT" -n demo get gateway global-external-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
  [[ -n "$VIP" ]] && break
  sleep 10
done

echo
printf '%s\n' '================ DEPLOYMENT COMPLETE ================'
echo "Project: $PROJECT_ID"
echo "Primary cluster: gke-primary"
echo "Secondary cluster: gke-secondary"
echo "Gateway IP: ${VIP:-pending}"
echo "Grafana password: $GRAFANA_PASSWORD"
echo "Grafana service: kubectl --context $PRIMARY_CONTEXT -n observability get svc grafana"
echo "Gateway status: kubectl --context $PRIMARY_CONTEXT -n demo get gateway,httproute"
echo "App A: http://${VIP:-GATEWAY_IP}/api/app-a/info"
echo "App B: http://${VIP:-GATEWAY_IP}/api/app-b/work?delay=500"
echo "Runtime credentials are under $RUNTIME_DIR and must not be committed."
echo '======================================================'
