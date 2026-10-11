# Lab 06. DELETE (Merge-on-Read)

## Цель

В Iceberg v2 удаление часто **не переписывает** data file: пишется delete file (position deletes: «файл + номер строки», или equality deletes: «удали строки с такими значениями колонок»). При чтении движок **сливает** data + deletes (Merge-on-Read).

## Подготовка

Нужна таблица с данными (после ETL или lab 05).

```bash
./scripts/run_sql.sh exercises/06-delete.sql
```

## StarRocks 4.0 vs 4.1

На живом `4.0-latest` DELETE падает так:

```
ERROR 1064: Table of iceberg catalog doesn't support [DELETE].
```

Официальный DML: `DELETE FROM` для Iceberg — **с v4.1**. Это ограничение версии, а не Iceberg.

Ближайший рабочий эквивалент на 4.0 — **overwrite без строки** (copy-on-write, не MoR). Готовый скрипт `06-delete.sql` делает именно это:

```sql
SET dynamic_overwrite = true;
INSERT OVERWRITE demo.sales.sales
SELECT sale_id, customer_id, amount, sale_date
FROM demo.sales.sales
WHERE sale_id <> 1;
```

После overwrite в `$files` **не** появятся `POSITION_DELETES`: старый data file просто не входит в новый snapshot (`operation = overwrite`). Time travel на предыдущий snapshot всё ещё покажет `sale_id = 1`.

Чтение чужих MoR-таблиц (delete files от Spark/Flink) StarRocks 4.0 умеет; в этой лабе нет второго движка, чтобы их создать.

## Что смотреть в MinIO (если DELETE прошёл)

В `warehouse/sales/sales/data/` (иногда `data/.../deletes/`):

- прежние `*.parquet` data;
- новые файлы deletes (часто `*.parquet` с колонками `file_path`, `pos`).

В `$files.content`: `0` = data, `1` = position deletes, `2` = equality deletes.

## Ожидаемый вывод (4.0, overwrite-эквивалент)

- COUNT = 5, строки `sale_id = 1` нет.
- `$files.content` только `0` (DATA), `position_delete_file_count = 0`.
- `VERSION AS OF` предыдущий snapshot: снова 6 строк, включая `sale_id = 1`.

На 4.1+ после настоящего `DELETE` ожидайте delete file (`content = 1` или `2`) и data parquet на месте.

## Вывод

MoR отделяет «факт удаления» от переписывания больших файлов. Compaction (`rewrite_data_files`, lab 07) позже может материализовать удаления в новые data files.
