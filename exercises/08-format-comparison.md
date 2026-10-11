# Lab 08. Сравнение форматов: Iceberg vs native DUPLICATE KEY

## Цель

Одни и те же продажи записать в:

1. **Iceberg** `demo.sales.sales_cmp` — файлы на MinIO, каталог REST, snapshots.
2. **Native StarRocks** `sales_native.sales_dup` — `DUPLICATE KEY` во внутреннем `default_catalog` (колоночные сегменты на BE).

Сравнить: time travel, schema change, ACID/снимок, привязка к движку, куда смотреть файлы.

Теория по Hive/Delta/Hudi — в [docs/03-formats.md](../docs/03-formats.md). Этот стенд их не поднимает.

## Подготовка

```bash
./scripts/run_sql.sh exercises/08-format-comparison.sql
```

## Что сделать

1. Посчитать строки в обеих таблицах (по 6).
2. Iceberg: `$snapshots` и `VERSION AS OF` первый snapshot → 3 строки.
3. Native: убедиться, что `$snapshots` / `VERSION AS OF` **нет** (раскомментируйте строки в SQL и получите ошибку).
4. `SHOW CREATE TABLE` — разные движки хранения.

На одном BE (этот compose) native-таблица требует `"replication_num" = "1"` — иначе `replication_num=3` не создастся.

## Что смотреть в MinIO

| Таблица | Где файлы |
|---------|-----------|
| Iceberg `sales_cmp` | MinIO `warehouse/sales/sales_cmp/data/*.parquet` + `metadata/` |
| Native `sales_dup` | **не в MinIO**. Данные на диске контейнера `starrocks-be` (внутренний формат сегментов). В бакете `warehouse` этой таблицы нет |

FE UI (порт 8030) показывает native tablet/replica; Iceberg — external catalog.

## Ожидаемый вывод (критерии)

| Критерий | Iceberg | Native DUPLICATE KEY |
|----------|---------|----------------------|
| Time travel | Да (`VERSION AS OF`, `$snapshots`) | Нет снимков Iceberg |
| Schema evolution | `ALTER` + старые parquet живы | `ALTER` есть, но это другой механизм (schema change job на BE), без open table format |
| ACID / изоляция | Snapshot isolation на уровне таблицы Iceberg | Транзакции загрузки StarRocks; нет внешнего snapshot log |
| Движок | Читают Spark/Trino/StarRocks/Flink по одному warehouse | Только этот кластер StarRocks |
| Файлы | Parquet + JSON/Avro metadata на S3 | Сегменты `.dat`/колоночный формат на BE |
| Партиции | Hidden `day(sale_date)` | Нужно `PARTITION BY` native (RANGE/expression) отдельно |
| Compaction | `rewrite_data_files` | Compaction/cumulative compaction BE |

Обе таблицы отвечают `SELECT COUNT(*) = 6`. Только Iceberg показывает `rows_at_first_snapshot = 3`.

## Вывод

Iceberg — **общий** слой хранения и метаданных для озера. Native-таблица — **движковый** OLAP с минимальной задержкой внутри StarRocks. Для учебного lakehouse и «нескольких движков к одним данным» берут Iceberg; для горячих витрин внутри кластера — native.
