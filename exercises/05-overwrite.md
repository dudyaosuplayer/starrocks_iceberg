# Lab 05. Append vs overwrite

## Цель

- **Append** (`INSERT INTO`) добавляет файлы, старый snapshot цел.
- **Overwrite** заменяет данные (партиции или всю таблицу) новым snapshot'ом. Старые parquet остаются на S3, пока snapshot не expire'ят.

Задача: «исправить» суммы day1, не потеряв day2 и не уничтожив историю.

## Подготовка

Лаба **пересоздаёт** `demo.sales.sales`. Labs 01–04 после этого нужно гонять заново с ETL.

```bash
./scripts/run_sql.sh exercises/05-overwrite.sql
```

## Что сделать

1. Два append (day1, day2) — как ETL, но `VALUES`.
2. `SET dynamic_overwrite = true` и `INSERT OVERWRITE` только строк за `2025-01-01` с новыми `amount`.
3. Сравнить текущий SELECT и `VERSION AS OF` первый snapshot.

Если `dynamic_overwrite` недоступен или overwrite снёс day2, используйте явный партиционный синтаксис (identity/трансформ зависит от версии):

```sql
INSERT OVERWRITE demo.sales.sales PARTITION (sale_date = '2025-01-01')
VALUES
    (1, 101, 111, DATE '2025-01-01'),
    (2, 102, 222, DATE '2025-01-01'),
    (3, 103, 333, DATE '2025-01-01');
```

Для hidden `day(sale_date)` предложение `PARTITION (...)` может требовать **значение трансформа**, а не исходную дату. Тогда оставьте `dynamic_overwrite` или перезапишите обе даты в одном `INSERT OVERWRITE`.

## Что смотреть в MinIO

После overwrite:

- новые parquet для партиции 2025-01-01;
- старые parquet day1 **ещё лежат** в `data/` (на них ссылается старый snapshot);
- day2 файлы те же, если сработала подмена одной партиции.

`$snapshots.operation` для overwrite обычно `overwrite` (не `append`).

## Ожидаемый вывод

| Момент | COUNT | amount для sale_id=1 |
|--------|------:|----------------------|
| До overwrite | 6 | 100 |
| После | 6 (day2 на месте) | 111 |
| VERSION AS OF первый snapshot | 3 | 100 |

Текущие day1: 111, 222, 333. Day2: 400, 500, 600.

## Вывод

Overwrite в Iceberg — новый snapshot, а не `rm` директории Hive. Поэтому time travel на «до исправления» работает.
