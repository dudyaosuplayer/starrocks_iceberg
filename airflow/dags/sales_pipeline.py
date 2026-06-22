from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id="sales_pipeline",
    start_date=datetime(2025, 1, 1),
    catchup=False,
) as dag:

    create_table = BashOperator(
        task_id="create_table",
        bash_command="""
        docker exec spark \
        spark-submit /opt/spark/jobs/create_table.py
        """
    )

    load_day1 = BashOperator(
        task_id="load_day1",
        bash_command="""
        docker exec spark \
        spark-submit /opt/spark/jobs/load_day1.py
        """
    )

    load_day2 = BashOperator(
        task_id="load_day2",
        bash_command="""
        docker exec spark \
        spark-submit /opt/spark/jobs/load_day2.py
        """
    )

    create_table >> load_day1 >> load_day2