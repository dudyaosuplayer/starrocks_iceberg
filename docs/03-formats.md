# Сравнение форматов таблиц

Стенд поднимает только Iceberg + native StarRocks. Delta, Hudi, Hive Metastore здесь нет — ниже сравнительная карта, чтобы выбрать формат осознанно.

## Кто за что отвечает

| Слой | Примеры | Роль |
|------|---------|------|
| File format | Parquet, ORC, Avro | Как закодированы колонки внутри файла |
| Table format | Iceberg, Delta Lake, Hudi, Hive table | Что такое «таблица»: снимок, схема, транзакция |
| Storage | S3, MinIO, HDFS | Байты |
| Engine | StarRocks, Spark, Trino | SQL и физический план |

Путать Parquet и Iceberg — самая частая ошибка. Parquet можно класть в Iceberg, Delta, Hudi и в «голую» Hive-таблицу.

## Таблица сравнения

| | Hive + Parquet | Apache Iceberg | Delta Lake | Apache Hudi | Native StarRocks |
|--|----------------|----------------|------------|-------------|------------------|
| Где метаданные | Metastore (часто только path + схема) | Catalog + JSON/Avro в object store | `_delta_log/` JSON/Parquet | Timeline в `.hoodie/` | FE + локальные реплики BE |
| Snapshot / time travel | Нет (или отдельно) | Да, first-class | Да (`VERSION AS OF`) | Да (savepoints / incremental) | Нет Iceberg-снимков |
| Hidden partitioning | Нет, Hive-пути | Да | В основном identity + generated cols | Зависит от layout | Свои RANGE/expression partition |
| Schema evolution | Ограничено, легко сломать файлы | Field ids, add/drop/rename | Сильная, свой протокол | Есть | Schema change job на BE |
| Deletes | Переписать партицию | v2 MoR delete files | Deletion vectors / rewrite | MoR или CoW | DELETE внутреннего движка |
| Много движков | Да, но слабо изолировано | Да (открытый spec) | Да, экосистема Databricks/Spark | Да, ориентация на upsert-стрим | Нет: данные привязаны к кластеру |
| Типичный write | Spark INSERT OVERWRITE dir | Любой Iceberg writer | Spark/Delta engine | Spark/Flink upsert | INSERT в native table |
| Когда брать | Легаси, простые dump-партиции | Озеро, несколько движков, ACID на S3 | Уже Delta-стек / Databricks | Тяжёлые CDC/upsert | Горячая витрина, низкая латентность |

## Iceberg vs native StarRocks (практика этого репо)

Lab 08 кладёт одни CSV-продажи в оба места.

**Iceberg (`demo.sales.sales`)**

- Файлы на MinIO, каталог REST.
- Другой движок теоретически читает ту же таблицу.
- Есть `$snapshots`, time travel, `rewrite_data_files`.
- План запроса ходит в S3: холоднее, чем native; помогает data cache BE.

**Native `DUPLICATE KEY` (`default_catalog`)**

- Сегменты на диске BE, репликация StarRocks.
- Быстрые point/scan внутри кластера, materialized views, внутренние индексы.
- Нет общего table format: выгрузить наружу = `INSERT INTO FILES()` / EXPORT.
- Нет `VERSION AS OF` в смысле Iceberg.

Правило большого пальца:

- сырьё и «источник правды» на озере, несколько потребителей → **Iceberg**;
- агрегат/витрина только для StarRocks, p99 важен → **native**;
- часто делают оба: Iceberg как слой хранения + native MV/таблица как ускоритель.

## Что сознательно не поднимаем

Spark, Nessie, Airflow, Hive Metastore, Flink, Delta, Hudi. Их можно вернуть позже как второй writer к тому же `s3://warehouse`, не ломая REST catalog.
