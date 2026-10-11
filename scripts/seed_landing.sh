#!/usr/bin/env bash
# Copy data/sales_day*.csv into MinIO bucket landing (stdin pipe, no bind-mount).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v docker.exe >/dev/null 2>&1 && docker.exe info >/dev/null 2>&1; then
  DOCKER=(docker.exe)
else
  echo "Docker is not available." >&2
  exit 1
fi

wait_mc() {
  local i
  for i in $(seq 1 60); do
    if "${DOCKER[@]}" exec mc /usr/bin/mc ls minio/landing >/dev/null 2>&1; then
      return 0
    fi
    echo "Waiting for MinIO mc... (${i}/60)"
    sleep 2
  done
  echo "mc is not ready (MinIO landing bucket)." >&2
  return 1
}

wait_mc

echo "Seeding s3://landing/sales_day1.csv"
"${DOCKER[@]}" exec -i mc /usr/bin/mc pipe minio/landing/sales_day1.csv < "${ROOT}/data/sales_day1.csv"
echo "Seeding s3://landing/sales_day2.csv"
"${DOCKER[@]}" exec -i mc /usr/bin/mc pipe minio/landing/sales_day2.csv < "${ROOT}/data/sales_day2.csv"
"${DOCKER[@]}" exec mc /usr/bin/mc ls minio/landing
