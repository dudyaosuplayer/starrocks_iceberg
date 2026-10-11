# Iceberg в StarRocks 4.0

Этот пет-проект повторяет [официальный Iceberg quick start](https://docs.starrocks.io/docs/quick_start/iceberg/): FE+BE, REST catalog, MinIO.

## Каталог

StarRocks не хранит Iceberg-таблицы во внутреннем `default_catalog`. Нужен **external catalog**:

```sql
CREATE EXTERNAL CATALOG 'demo'
PROPERTIES (
  "type"="iceberg",
  "iceberg.catalog.type"="rest",
  "iceberg.catalog.uri"="http://iceberg-rest:8181",
  "iceberg.catalog.warehouse"="warehouse",
  "aws.s3.access_key"="admin",
  "aws.s3.secret_key"="password",
  "aws.s3.endpoint"="http://minio:9000",
  "aws.s3.enable_path_style_access"="true"
);
```

Для MinIO официально рекомендуют **REST**, не Hadoop catalog. Path-style (`enable_path_style_access=true`) обязателен: MinIO плохо живёт с virtual-hosted `bucket.minio`.

Имена в этом репозитории: каталог `demo`, БД `sales`, таблица `demo.sales.sales`.

## Путь записи

```
SQL INSERT
  → BE пишет Parquet в s3://warehouse/...
  → commit snapshot через REST catalog
  → новый metadata JSON в warehouse
```

Ограничение: **write только Parquet**. ORC/Avro Iceberg StarRocks не пишет (читать чужие форматы — смотрите актуальную матрицу в документации).

Чтение CSV из `s3://landing` идёт через table function `FILES()`, это **не** Iceberg: CSV — staging, потом `INSERT INTO iceberg SELECT FROM FILES(...)`.

## Метаданные и кэш

FE кэширует Iceberg metadata (таблица, манифесты, delete files). Если таблицу меняет другой движок, кэш может отстать. Имеет смысл `REFRESH EXTERNAL TABLE demo.sales.sales` (и/или подождать TTL кэша).

В этом учебном контуре пишет только StarRocks, поэтому после своих `INSERT` данные обычно видны сразу.

Метатаблицы (с 3.4.1): `table$snapshots`, `$files`, `$manifests`, `$history`, `$partitions`, `$refs`. Синтаксис — суффикс `$имя` к имени таблицы, без точки: `demo.sales.sales$snapshots`.

## Time travel

С 3.4.0:

```sql
SELECT * FROM demo.sales.sales VERSION AS OF <snapshot_id>;
SELECT * FROM demo.sales.sales TIMESTAMP AS OF '2026-08-27 12:00:00';
```

Ветки/теги: `ALTER TABLE ... CREATE BRANCH/TAG` — в labs не обязательны.

## Procedures (без Spark)

С 4.0 ручной compaction:

```sql
ALTER TABLE demo.sales.sales
EXECUTE rewrite_data_files("min_file_size_bytes"=134217728) [WHERE sale_date = '2025-01-01'];
```

Это замена типичного Spark job `rewriteDataFiles`. Expire snapshots / remove orphan files — отдельные procedures в документации; для курса достаточно compaction.

## DML

| Операция | Версия / заметка |
|----------|------------------|
| `INSERT` / `INSERT OVERWRITE` | с 3.1, только Parquet |
| Hidden `PARTITION BY (day(col))` | transforms: `year/month/day/hour/bucket/truncate`. Для DATE в 4.0 нужен `day()`, не `days()` |
| `SET dynamic_overwrite = true` | с 3.4: overwrite только затронутых партиций |
| `ALTER TABLE ADD COLUMN` | schema evolution, колонка NULL-able |
| `DELETE FROM` Iceberg | **не в 4.0** (`doesn't support [DELETE]`); в документации с 4.1. Lab 06: overwrite-эквивалент |
| `rewrite_data_files` | с 4.0 |

## Что не путать с FE

- **FE** (`default_catalog`) — внутренние native-таблицы, метаданные в своей БД FE.
- **Iceberg catalog** — внешний сервис (у нас REST на `:8181`).
- **MinIO** — байты parquet/json/avro. Потеряли бакет `warehouse` — таблица «есть» в REST как имя, данных нет.

Порты и запуск: [README](../README.md). Сравнение форматов: [03-formats.md](03-formats.md).
