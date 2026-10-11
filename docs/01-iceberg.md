# Apache Iceberg: короткий конспект

Iceberg — **open table format** для больших аналитических таблиц на object storage. Это не файловый формат (как Parquet) и не query engine (как StarRocks). Это спецификация, как из набора файлов сделать таблицу со схемой, партициями, транзакциями и историей.

## Спецификация: из чего состоит таблица

```
catalog (REST / Hive / Glue / JDBC / Nessie)
  └── table
        ├── metadata/*.json     текущая схема, snapshot-log, partition spec
        ├── metadata/*.avro     manifest list + manifests
        └── data/*.parquet      данные (StarRocks пишет только Parquet)
```

**Catalog** знает, где лежит *текущий* metadata file таблицы. Сами данные catalog не хранит.

**Snapshot** — атомарная версия таблицы: набор data (и delete) files. Новый commit = новый snapshot. Читатели видят один снимок целиком (snapshot isolation): нет «наполовину дописанной» таблицы.

**Manifest list** — Avro-файл со списком manifests данного snapshot.

**Manifest** — Avro со списком data/delete files, partition values, min/max по колонкам. Планировщик отсекает файлы, не подходящие под фильтр.

**Data files** — обычно Parquet. Имена файлов сами по себе не есть таблица: без манифестов это просто объекты в бакете.

Отличие от «папки Parquet»: Hive/Spark часто считают таблицей *все файлы в path*. Iceberg считает таблицей *только файлы, перечисленные в текущем snapshot*. Мусор, незакоммиченные и устаревшие файлы в path не читаются.

## Hidden partitioning

Партиция задаётся **трансформом** колонки (`days(ts)`, `bucket(id, N)`, `truncate(s, 10)`), а не отдельной колонкой, которую обязан заполнять ETL.

Пользователь пишет `WHERE sale_date = '2025-01-01'`. Движок вычисляет transform `day(sale_date)` и prune по partition spec. Путь в S3 **не обязан** выглядеть как Hive `sale_date=2025-01-01/`.

В SQL StarRocks 4.0 пишите `PARTITION BY (day(sale_date))`. Конструкция `days(sale_date)` из Spark/спеки на типе DATE отклоняется (`__iceberg_transform_days(date)`).

## Эволюция схемы и партиций

- **Schema evolution**: add/drop/rename/widen колонок в metadata. Старые Parquet не переписываются: колонки связаны **field id**, не позицией и не только именем.
- **Partition evolution**: новый spec (например, добавить `bucket`) действует для *новых* файлов; старые читаются по старому spec. Этого нет у классического Hive `PARTITIONED BY`.

## Iceberg v2 deletes (MoR)

v1 по сути только overwrite файлов. v2 добавляет **delete files**:

| Тип | Смысл |
|-----|--------|
| Position deletes | «в файле X строка с offset Y удалена» |
| Equality deletes | «удали строки, где колонки равны этим значениям» |

Чтение = merge data + deletes (**Merge-on-Read**). Compaction позже может переписать data files уже без удалённых строк (Copy-on-Write материализация).

## Зачем это lakehouse

Несколько движков (StarRocks, Spark, Trino, Flink) могут писать/читать **одну** таблицу, если говорят на Iceberg и смотрят в один catalog + warehouse. Транзакции и time travel — свойства формата, не конкретного SQL-движка.

Дальше по стеку этого репозитория: [02-starrocks.md](02-starrocks.md). Сравнение с Delta/Hudi/native: [03-formats.md](03-formats.md).
