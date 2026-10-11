# Lab 03. Hidden partitioning

## Цель

Таблица партиционирована `PARTITION BY (day(sale_date))`, но в схеме **нет** колонки `sale_date_day`. Фильтр пишется по `sale_date`. Iceberg сам вычисляет transform и отсекает файлы (partition prune). Это и есть hidden partitioning — в отличие от Hive-пути `sale_date=2025-01-01/`.

## Подготовка

```bash
./scripts/run_sql.sh exercises/03-partitions.sql
```

## Что сделать

1. `$partitions` — значения партиций (день от `sale_date`).
2. `$files.file_path` — как physically лежат parquet.
3. `EXPLAIN` для `WHERE sale_date = '2025-01-01'` vs полный скан.

## Что смотреть в MinIO

В `warehouse/sales/sales/data/`:

- StarRocks 4.0 кладёт parquet в Hive-подобные каталоги трансформа: `data/sale_date_day=2025-01-01/...` и `data/sale_date_day=2025-01-02/...` (имя партиции — **transform**, не колонка `sale_date`);
- фильтр в SQL всё равно `WHERE sale_date = '2025-01-01'`, без колонки `sale_date_day`.

Сравните: в классическом Hive/Spark `PARTITIONED BY (sale_date)` путь почти всегда `sale_date=2025-01-01/`.

## Ожидаемый вывод

- Два значения партиции: день `2025-01-01` и `2025-01-02` (в `$partitions.partition_value`).
- `WHERE sale_date = '2025-01-01'` → 3 строки (`sale_id` 1–3).
- `EXPLAIN`: в плане Iceberg видны предикаты / меньшее число сканируемых файлов, чем у `SELECT *` без фильтра.

Если prune не виден в текстовом `EXPLAIN`, смотрите `EXPLAIN VERBOSE` или просто `$files` + фильтр: файлы с `upper_bounds`/`lower_bounds` вне даты не нужны.

## Вывод

Пользователь фильтрует по «бизнес-колонке». Спека Iceberg отделяет **partition spec** от схемы таблицы, поэтому позже можно сменить spec (partition evolution) без переписывания всех данных.
