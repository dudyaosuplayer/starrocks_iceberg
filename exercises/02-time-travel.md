# Lab 02. Снапшоты и time travel

## Цель

Увидеть, что каждый `INSERT` создаёт **новый snapshot**. Текущая таблица — это «голова» лога. Старые снимки остаются, пока их не expire'ит maintenance. StarRocks 3.4+ умеет `VERSION AS OF` и `TIMESTAMP AS OF`.

## Подготовка

ETL уже сделал два append: day1 (3 строки), day2 (ещё 3).

```bash
./scripts/run_sql.sh exercises/02-time-travel.sql
```

Если подзапрос в `VERSION AS OF` не поддерживается (ошибка `Invalid version value ... Subquery`), сохраните id во **user-variable**:

```sql
SET @first_snapshot = (
    SELECT snapshot_id FROM demo.sales.sales$snapshots ORDER BY committed_at LIMIT 1
);
SELECT COUNT(*) FROM demo.sales.sales VERSION AS OF @first_snapshot;
SELECT * FROM demo.sales.sales VERSION AS OF @first_snapshot ORDER BY sale_id;
```

Либо подставьте числовой `snapshot_id` из `$snapshots` напрямую.

`TIMESTAMP AS OF now()` совпадает с текущим COUNT. Литерал с микросекундами из `committed_at` (например `2026-08-27 17:25:31.332000`) StarRocks 4.0 отвергает (`Invalid temporal version`). Возьмите время **без дроби секунды** чуть позже первого коммита:

```sql
SELECT COUNT(*) FROM demo.sales.sales TIMESTAMP AS OF '2026-08-27 17:25:32';
```

## Что смотреть в MinIO

В `warehouse/sales/sales/metadata/`:

- несколько `*.json` — после каждого коммита новый metadata file, старый **не удаляется**;
- snapshot log внутри JSON (`snapshots`, `snapshot-log`) указывает на разные manifest-list.

Data Parquet day1 **остаются** после load day2: новый snapshot добавляет файлы, а не переписывает старые (copy-on-write append).

## Ожидаемый вывод

| Запрос | Строк |
|--------|------:|
| `SELECT COUNT(*) FROM demo.sales.sales` | 6 |
| `VERSION AS OF` первый snapshot | 3 (`sale_id` 1,2,3; только `2025-01-01`) |
| Текущий SELECT | `sale_id` 1..6 |

`$snapshots.operation` = `append`. У второго снэпшота `parent_id` = id первого.

## Вывод

Time travel — это не бэкап кластера, а чтение **другого snapshot_id** той же таблицы. Native-таблица StarRocks так не умеет (см. lab 08).
