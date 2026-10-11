#!/usr/bin/env bash
# Create Iceberg catalog + sales table, load day1 then day2 from MinIO landing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

run_sql() {
  "${ROOT}/scripts/run_sql.sh" "$@"
}

echo "==> Seeding MinIO landing CSV"
"${ROOT}/scripts/seed_landing.sh"

echo "==> Creating Iceberg REST catalog demo (ok if it already exists)"
set +e
catalog_out="$("${ROOT}/scripts/run_sql.sh" "${ROOT}/sql/00_catalog.sql" 2>&1)"
catalog_rc=$?
set -e
echo "${catalog_out}"
if [[ ${catalog_rc} -ne 0 ]]; then
  if echo "${catalog_out}" | grep -qiE 'already exist|exists'; then
    echo "Catalog demo already exists, continuing."
  else
    echo "Failed to create catalog." >&2
    exit "${catalog_rc}"
  fi
fi

echo "==> CREATE TABLE + load CSV day1/day2"
run_sql \
  "${ROOT}/sql/etl/01_create_table.sql" \
  "${ROOT}/sql/etl/02_load_day1.sql" \
  "${ROOT}/sql/etl/03_load_day2.sql" \
  "${ROOT}/sql/etl/04_verify.sql"

echo "==> ETL done. Table: demo.sales.sales"
echo "    MinIO warehouse: http://localhost:9001  (admin / password)"
echo "    Objects: warehouse/sales/sales/"
