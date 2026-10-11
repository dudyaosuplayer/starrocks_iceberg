# Lab 01. Анатомия таблицы Iceberg

## Цель

Понять, что Iceberg — это **table format**, а не «ещё один Parquet». Данные живут в Parquet-файлах на MinIO, а **снимок таблицы** — это JSON-метаданные + манифесты, которые говорят, какие файлы входят в текущую версию.

## Подготовка

```bash
docker compose up --detach --wait --wait-timeout 400
./scripts/run_etl.sh
./scripts/run_sql.sh exercises/01-anatomy.sql
```

## Что сделать

1. Выполнить `SHOW CREATE TABLE demo.sales.sales` — схема и `PARTITION BY day(sale_date)`.
2. Прочитать текущие строки: 6 продаж за 2025-01-01 и 2025-01-02.
3. Запросить метатаблицы `$snapshots`, `$files`, `$manifests`, `$history`.
4. Открыть MinIO Console и сопоставить SQL с объектами на диске.

## Что смотреть в MinIO

Консоль: http://localhost:9001 (логин `admin` / `password`).

Бакет **warehouse** → `sales/sales/` (путь может быть `warehouse/sales/sales/`):

| Путь | Зачем |
|------|--------|
| `metadata/*.json` | Текущий и прошлые metadata files (схема, snapshot-log, partition spec) |
| `metadata/snap-*.avro` или `*.avro` в metadata | Manifest list / manifests: список data files снэпшота |
| `data/**/*.parquet` | Данные. Имена **не** обязаны содержать `sale_date=2025-01-01/` — это hidden partitioning |

Бакет **landing** — исходные CSV, Iceberg их не «превращает» в таблицу: StarRocks прочитал CSV через `FILES()` и **записал новые Parquet** в warehouse.

## Ожидаемый вывод

- `DESC` / `SHOW CREATE TABLE`: колонки `sale_id`, `customer_id`, `amount`, `sale_date`, партиция `PARTITION BY day(sale_date)`.
- `SELECT`: 6 строк, `sale_id` 1..6.
- `$snapshots`: минимум **два** снэпшота (`append` после day1 и после day2), у второго `parent_id` = id первого.
- `$files`: несколько Parquet (`file_format = parquet`, `content = DATA` / `0`), не CSV.
- `$history`: цепочка `made_current_at` / `snapshot_id`.

## Вывод

Запрос «SELECT * FROM demo.sales.sales» **не сканирует каталог файлов как Hive**. Движок читает текущий snapshot из каталога REST + metadata JSON, затем только те Parquet, которые перечислены в манифестах.
