# Iceberg + StarRocks (учебный lakehouse)

Локальный стенд на Docker: **StarRocks 4.0** пишет и читает **Apache Iceberg** через **REST-каталог** и **MinIO**. CSV с продажами попадают в бакет `landing`, затем SQL-ETL грузит их в таблицу `demo.sales.sales`.

Теория: [docs/01-iceberg.md](docs/01-iceberg.md), [docs/02-starrocks.md](docs/02-starrocks.md), [docs/03-formats.md](docs/03-formats.md).  
Практикум: [exercises/](exercises/) (labs 01–08).

## Что в стеке

| Сервис | Образ | Зачем |
|--------|--------|--------|
| `starrocks-fe` | `starrocks/fe-ubuntu:4.0-latest` | SQL, mysql-протокол |
| `starrocks-be` | `starrocks/be-ubuntu:4.0-latest` | Сканы и запись Parquet |
| `rest` | `apache/iceberg-rest-fixture` | Iceberg REST catalog |
| `minio` | `minio/minio:RELEASE.2024-10-29T16-01-48Z` | S3: `warehouse` + `landing` |
| `mc` | `minio/mc:RELEASE.2024-10-29T15-34-59Z` | Создаёт бакеты и копирует CSV |

Spark и Airflow в основной путь **не входят**.

Имена:

- каталог Iceberg: `demo`
- база: `sales`
- таблица: `demo.sales.sales`
- колонки: `sale_id BIGINT`, `customer_id BIGINT`, `amount DOUBLE`, `sale_date DATE`
- партиция: `PARTITION BY (day(sale_date))` (в 4.0 не `days()` — нет сигнатуры для DATE)

## Быстрый старт

Нужны Docker Compose и несколько гигабайт RAM (на WSL лучше не жать память Docker). Первый `up` качает образы StarRocks (~гигабайты) и может занять много минут: FE/BE поднимаются не сразу.

```bash
docker compose up --detach --wait --wait-timeout 400
./scripts/run_etl.sh
```

На WSL, если Linux-команда `docker` пишет про «activate the WSL integration», используйте клиент Windows из того же каталога:

```bash
docker.exe compose up --detach --wait --wait-timeout 400
```

`scripts/run_sql.sh` / `run_etl.sh` сами переключаются на `docker.exe`, если Linux-`docker` недоступен.

CSV в бакет `landing` копирует `scripts/seed_landing.sh` (вызывается из `run_etl.sh`) через `mc pipe`, без bind-mount каталога `data/`. Так стенд поднимается и в WSL без интеграции Docker Desktop.

`--wait` ждёт healthcheck FE и BE. Если таймаут — смотрите логи, не перезапускайте сразу всё подряд:

```bash
docker compose ps
docker compose logs --tail=80 starrocks-fe
docker compose logs --tail=80 starrocks-be
docker compose logs --tail=80 rest
docker compose logs --tail=80 mc
```

Остановка:

```bash
docker compose down
```

Данные в контейнерах без именованных volume: `down -v` не обязателен, но новый `up` после `down` — чистый кластер, ETL нужно прогнать снова.

## Порты

| Порт | Сервис |
|------|--------|
| 9030 | MySQL-протокол StarRocks (SQL) |
| 8030 | FE HTTP |
| 8040 | BE HTTP |
| 9020 | FE (rpc, как в официальном quick start) |
| 8181 | Iceberg REST |
| 9000 | MinIO S3 API |
| 9001 | MinIO Console |

## Клиент SQL

Из контейнера FE (mysql уже внутри образа):

```bash
docker exec -it starrocks-fe mysql -P 9030 -h 127.0.0.1 -u root --prompt="StarRocks > "
```

Со хоста, если установлен клиент:

```bash
mysql -P 9030 -h 127.0.0.1 -u root --prompt="StarRocks > "
```

Произвольный файл:

```bash
./scripts/run_sql.sh sql/etl/04_verify.sql
```

## MinIO Console

Откройте http://localhost:9001

- пользователь: `admin`
- пароль: `password`

Бакеты:

- `landing` — `sales_day1.csv`, `sales_day2.csv` (кладёт сервис `mc` при старте);
- `warehouse` — Iceberg metadata + Parquet (`warehouse/sales/sales/` после ETL).

## ETL

`./scripts/run_etl.sh` делает:

1. `CREATE EXTERNAL CATALOG demo` (REST + MinIO path-style) — [sql/00_catalog.sql](sql/00_catalog.sql)
2. `CREATE DATABASE sales` + таблица `demo.sales.sales`
3. `INSERT ... SELECT FROM FILES()` для `s3://landing/sales_day1.csv`
4. То же для `sales_day2.csv` (второй snapshot)
5. Проверки: `SELECT`, `$snapshots`, `$files`

Повторный запуск **пересоздаёт** таблицу `demo.sales.sales`.

Исходники CSV: [data/sales_day1.csv](data/sales_day1.csv), [data/sales_day2.csv](data/sales_day2.csv).

## Лабораторные

Порядок рассчитан на данные после ETL. Labs 05 и 08 **пересоздают** свои таблицы; 04/06 меняют `demo.sales.sales` — при необходимости снова `./scripts/run_etl.sh`.

| Lab | Тема | Файлы |
|-----|------|--------|
| 01 | Анатомия таблицы Iceberg | [exercises/01-anatomy.md](exercises/01-anatomy.md) |
| 02 | Снапшоты и time travel | [exercises/02-time-travel.md](exercises/02-time-travel.md) |
| 03 | Hidden partitioning | [exercises/03-partitions.md](exercises/03-partitions.md) |
| 04 | Schema evolution | [exercises/04-schema-evolution.md](exercises/04-schema-evolution.md) |
| 05 | Append vs overwrite | [exercises/05-overwrite.md](exercises/05-overwrite.md) |
| 06 | DELETE (MoR) | [exercises/06-delete.md](exercises/06-delete.md) |
| 07 | Small files + compaction | [exercises/07-compaction.md](exercises/07-compaction.md) |
| 08 | Iceberg vs native DUPLICATE KEY | [exercises/08-format-comparison.md](exercises/08-format-comparison.md) |

Пример:

```bash
./scripts/run_sql.sh exercises/01-anatomy.sql
./scripts/run_sql.sh exercises/02-time-travel.sql
```

## Структура репозитория

```
docker-compose.yml
data/                 CSV (не удалять)
sql/00_catalog.sql
sql/etl/              CREATE TABLE + FILES() load
scripts/run_sql.sh
scripts/run_etl.sh
scripts/seed_landing.sh
docs/                 теория (RU)
exercises/            labs 01–08 (RU markdown + SQL)
```

Пустые каталоги `spark/` и `airflow/` могут остаться, если их создали от root: в учебный путь они не входят.
