from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import os
import sys

# Ajouter le chemin du projet pour importer les modules
PROJECT_PATH = "/opt/airflow/project"
sys.path.insert(0, PROJECT_PATH)

# Configuration par défaut du DAG
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
}


def capture_data_from_minio():
    """Télécharge les nouveaux fichiers depuis MinIO."""
    from dotenv import load_dotenv
    import boto3
    import psycopg2

    # Charger les variables d'environnement
    load_dotenv(os.path.join(PROJECT_PATH, ".env"))

    def get_db_config():
        return {
            "host": os.getenv("DB_HOST"),
            "port": os.getenv("DB_PORT"),
            "dbname": os.getenv("DB_NAME"),
            "user": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
        }

    def get_last_processed_file():
        schema = os.getenv("DB_SCHEMA")
        cfg = get_db_config()
        conn = psycopg2.connect(**cfg)
        cur = conn.cursor()
        cur.execute(f"SELECT last_file_processed FROM {schema}.snapshot WHERE id = 1")
        result = cur.fetchone()
        cur.close()
        conn.close()
        return result[0] if result else None

    # Créer le client S3/MinIO
    s3 = boto3.client(
        service_name=os.getenv("SERVICE_NAME"),
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        endpoint_url=os.getenv("ENDPOINT_URL")
    )

    # Bucket et répertoire local
    bucket_name = os.getenv("BUCKET_NAME")
    local_dir = os.path.join(PROJECT_PATH, "data")
    os.makedirs(local_dir, exist_ok=True)

    # Récupérer le dernier fichier traité
    last_processed = get_last_processed_file()
    print(f"Dernier fichier traité : {last_processed or 'Aucun (première exécution)'}")

    # Lister les objets du bucket
    response = s3.list_objects_v2(Bucket=bucket_name)
    all_files = [obj["Key"] for obj in response.get("Contents", [])]

    # Filtrer les nouveaux fichiers
    if last_processed:
        new_files = [f for f in all_files if f.endswith(".log") and f > last_processed]
    else:
        new_files = [f for f in all_files if f.endswith(".log")]

    new_files.sort()
    print(f"Fichiers à traiter : {len(new_files)}")

    # Télécharger les nouveaux fichiers
    for file_key in new_files:
        local_path = os.path.join(local_dir, file_key)
        s3.download_file(bucket_name, file_key, local_path)
        print(f"  ✓ Téléchargé : {file_key}")

    return new_files


def ingest_data_to_bronze():
    """Ingère les données dans la table Bronze."""
    from dotenv import load_dotenv
    import psycopg2
    from pathlib import Path

    # Charger les variables d'environnement
    load_dotenv(os.path.join(PROJECT_PATH, ".env"))

    def get_db_config():
        return {
            "host": os.getenv("DB_HOST"),
            "port": os.getenv("DB_PORT"),
            "dbname": os.getenv("DB_NAME"),
            "user": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
        }

    def update_snapshot(cursor, schema, last_file):
        cursor.execute(f"""
            INSERT INTO {schema}.snapshot (id, last_file_processed, updated_at)
            VALUES (1, %s, NOW())
            ON CONFLICT (id) DO UPDATE SET
                last_file_processed = EXCLUDED.last_file_processed,
                updated_at = NOW()
        """, (last_file,))

    def clear_data_folder(data_dir):
        deleted_count = 0
        for file_path in data_dir.glob("*"):
            if file_path.is_file():
                file_path.unlink()
                deleted_count += 1
        return deleted_count

    schema = os.getenv("DB_SCHEMA")
    cfg = get_db_config()
    data_dir = Path(PROJECT_PATH) / "data"

    conn = psycopg2.connect(**cfg)
    cur = conn.cursor()

    log_files = sorted(data_dir.glob("*.log"))
    print(f"Fichiers trouvés : {len(log_files)}")

    if not log_files:
        print("Aucun fichier à traiter.")
        cur.close()
        conn.close()
        return

    total_lines = 0
    last_file_name = None

    for log_file in log_files:
        print(f"Traitement de : {log_file.name}")
        last_file_name = log_file.name

        with open(log_file, "r", encoding="utf-8") as f:
            for line in f:
                line_content = line.strip()
                if line_content:
                    cur.execute(
                        f"INSERT INTO {schema}.bronzetable (logs) VALUES (%s)",
                        (line_content,)
                    )
                    total_lines += 1

    if last_file_name:
        update_snapshot(cur, schema, last_file_name)
        print(f"Snapshot mis à jour : {last_file_name}")

    conn.commit()
    cur.close()
    conn.close()

    print(f"Total lignes ingérées : {total_lines}")

    deleted = clear_data_folder(data_dir)
    print(f"Dossier data/ nettoyé : {deleted} fichier(s) supprimé(s)")


# Définition du DAG
with DAG(
    dag_id="dag_ingestion",
    default_args=default_args,
    description="Capture des logs depuis MinIO et ingestion dans Bronze",
    schedule_interval="*/20 * * * *",  # Toutes les 20 minutes
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["ingestion", "bronze", "minio"],
) as dag:

    task_capture = PythonOperator(
        task_id="capture_data_from_minio",
        python_callable=capture_data_from_minio,
    )

    task_ingest = PythonOperator(
        task_id="ingest_data_to_bronze",
        python_callable=ingest_data_to_bronze,
    )

    # Définir l'ordre des tâches
    task_capture >> task_ingest
