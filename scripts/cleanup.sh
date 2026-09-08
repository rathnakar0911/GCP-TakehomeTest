#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
read -r -p "This will destroy the assessment infrastructure in ${PROJECT_ID}. Type DELETE to continue: " answer
[[ "$answer" == "DELETE" ]] || exit 1
terraform -chdir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)" destroy -auto-approve
