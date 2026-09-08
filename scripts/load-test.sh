#!/usr/bin/env bash
set -euo pipefail
VIP="${1:?Usage: ./load-test.sh GATEWAY_IP}"
for i in $(seq 1 100); do
  curl -sS "http://${VIP}/api/app-a/hello" >/dev/null || true
  curl -sS "http://${VIP}/api/app-b/work?delay=$((RANDOM % 700))" >/dev/null || true
  if (( i % 10 == 0 )); then curl -sS "http://${VIP}/api/app-b/error" >/dev/null || true; fi
  sleep 0.2
done
echo 'Traffic generation complete. Allow a few minutes for Monitoring/BigQuery ingestion.'
