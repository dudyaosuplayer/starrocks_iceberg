#!/usr/bin/env bash
# Run one or more .sql files against StarRocks FE (mysql protocol on 9030).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# WSL: Linux `docker` may be a Desktop stub until distro integration is on.
if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v docker.exe >/dev/null 2>&1 && docker.exe info >/dev/null 2>&1; then
  DOCKER=(docker.exe)
else
  echo "Docker is not available. Install Docker Desktop and enable WSL integration, or use docker.exe." >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sql-file> [sql-file...]" >&2
  exit 1
fi

MYSQL=("${DOCKER[@]}" exec -i starrocks-fe mysql -P 9030 -h 127.0.0.1 -u root --table)

wait_ready() {
  local i
  for i in $(seq 1 90); do
    if "${DOCKER[@]}" exec starrocks-fe mysql -P 9030 -h 127.0.0.1 -u root -N -e "SELECT 1" >/dev/null 2>&1; then
      if "${DOCKER[@]}" exec starrocks-fe mysql -P 9030 -h 127.0.0.1 -u root -e "SHOW BACKENDS\G" 2>/dev/null | grep -q "Alive: true"; then
        return 0
      fi
    fi
    echo "Waiting for StarRocks FE/BE... (${i}/90)"
    sleep 5
  done
  echo "StarRocks is not ready. Check: docker compose ps && docker compose logs starrocks-fe starrocks-be" >&2
  return 1
}

wait_ready

for f in "$@"; do
  if [[ ! -f "${f}" ]]; then
    echo "SQL file not found: ${f}" >&2
    exit 1
  fi
  echo "======== ${f} ========"
  "${MYSQL[@]}" < "${f}"
  echo
done
