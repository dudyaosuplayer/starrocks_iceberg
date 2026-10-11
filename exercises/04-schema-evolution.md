# Lab 04. Schema evolution

## Цель

`ALTER TABLE ... ADD COLUMN` меняет **схему в metadata**, а не переписывает старые Parquet. Старые файлы остаются валидными: у новых колонок в них нет значений → при чтении `NULL`. Iceberg сверяет колонки по **field id**, не по позиции в файле.

## Подготовка

Лаба меняет `demo.sales.sales`. Прогоняйте **после** labs 01–03 и **до** labs, которым нужна исходная схема — либо заново `./scripts/run_etl.sh`.

```bash
./scripts/run_sql.sh exercises/04-schema-evolution.sql
```

## Что сделать

1. `DESC` до и после `ADD COLUMN region STRING`.
2. `SELECT` старых строк: `region` = NULL.
3. `INSERT` строки с `region = 'eu'`.
4. Time travel на первый snapshot: только 3 строки day1; колонка `region` либо отсутствует в проекции, либо NULL.

## Что смотреть в MinIO

- Новый `metadata/*.json` с `schema-id` больше прежнего и новым полем `region`.
- Старые `data/*.parquet` **не исчезают** и не перезаписываются из-за ALTER.
- Появляется новый parquet только от `INSERT` с `sale_id = 7`.

## Ожидаемый вывод

```
sale_id | region
      1 | NULL
      ...
      6 | NULL
      7 | eu
```

`SHOW CREATE TABLE` содержит `region`.

## Ограничения StarRocks 4.0

- Добавляемая колонка должна быть NULL-able (Iceberg/StarRocks не заполняют default в старых файлах).
- `DROP`/`RENAME` тоже поддерживаются движком, но в этой лабе достаточно ADD.
- После ALTER FE может кэшировать схему; если `DESC` «старый», выполните повторный `DESC` / переподключитесь.

## Вывод

Эволюция схемы — свойство table format. У набора «сырых» Parquet в директории без манифестов такой контракт нет.
