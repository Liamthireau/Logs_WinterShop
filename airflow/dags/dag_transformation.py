from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

# Configuration par défaut du DAG
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# Chemin du projet dbt
PROJECT_PATH = "/opt/airflow/project"

# Définition du DAG
with DAG(
    dag_id="dag_transformation",
    default_args=default_args,
    description="Transformation des données avec dbt (Silver et Gold)",
    schedule_interval="0 * * * *",  # Toutes les heures
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["transformation", "dbt", "silver", "gold"],
) as dag:

    # Tâche : dbt run pour Silver
    task_dbt_silver = BashOperator(
        task_id="dbt_run_silver",
        bash_command=f"cd {PROJECT_PATH} && dbt run --select silvertable --target prod --profiles-dir {PROJECT_PATH}",
    )

    # Tâche : dbt run pour Gold
    task_dbt_gold = BashOperator(
        task_id="dbt_run_gold",
        bash_command=f"cd {PROJECT_PATH} && dbt run --select goldtable_* --target prod --profiles-dir {PROJECT_PATH}",
    )

    # Tâche optionnelle : dbt test pour valider les données
    task_dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {PROJECT_PATH} && dbt test --target prod --profiles-dir {PROJECT_PATH}",
    )

    # Définir l'ordre des tâches
    task_dbt_silver >> task_dbt_gold >> task_dbt_test
