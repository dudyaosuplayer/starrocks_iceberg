# Lab 07. Small files и compaction

## Цель

Каждый маленький `INSERT` = отдельный commit ≈ отдельный Parquet. Много мелких файлов раздувает манифесты и план запроса. В Spark это `rewrite_data_files` / Spark Actions. **StarRocks 4.0** умеет то же SQL-процедурой, без Spark:

```sql
ALTER TABLE ... EXECUTE rewrite_data_files("min_file_size_bytes"=..., "rewrite_all"=true);
```

## Подготовка

Используется отдельная таблица `demo.sales.sales_small_files`, основная `sales` не трогается.

```bash
./scripts/run_sql.sh exercises/07-compaction.sql
```

## Что сделать

1. Шесть отдельных `INSERT VALUES` в одну партицию.
2. `SELECT COUNT(*) FROM ...$files` — ожидается ~6 data files.
3. `rewrite_data_files` с порогом 128 MiB (все файлы «маленькие»).
4. Снова посчитать файлы и строки.

## Что смотреть в MinIO

`warehouse/sales/sales_small_files/`:

- до compaction: много крошечных parquet в `data/`;
- после: новый(е) более крупный parquet, старые файлы ещё на диске (на них ссылаются старые snapshots), текущий snapshot указывает на переписанные.

## Ожидаемый вывод

| Этап | `$files` | `COUNT(*)` строк |
|------|----------|------------------|
| До | около 6 | 6 |
| После | 1 (или мало) | 6, те же `sale_id` 1–6 |

Последний `$snapshots.operation` часто `replace` (переписали файлы, логические данные те же).

Если `rewrite_all` не принимается, вызовите только `"min_file_size_bytes"=134217728`. Не используйте алиасы `AS files` / `AS rows` — в 4.0 это зарезервированные слова и ломают разбор `$files`.

## Вывод

Maintenance Iceberg (compaction, expire snapshots) в этом стеке делается **из StarRocks SQL**, а не отдельным Spark-job. Это главное отличие учебного контура от «классического» Spark+Iceberg.
