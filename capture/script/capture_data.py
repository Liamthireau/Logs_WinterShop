import os
from dotenv import load_dotenv
import boto3
import psycopg2

# Charger les variables d'environnement
load_dotenv()


def get_db_config():
    return {
        "host": os.getenv("DB_HOST"),
        "port": os.getenv("DB_PORT"),
        "dbname": os.getenv("DB_NAME"),
        "user": os.getenv("DB_USER"),
        "password": os.getenv("DB_PASSWORD"),
    }


def get_last_processed_file():
    """Récupère le nom du dernier fichier traité depuis la table snapshot."""
    schema = os.getenv("DB_SCHEMA")
    cfg = get_db_config()

    conn = psycopg2.connect(**cfg)
    cur = conn.cursor()

    cur.execute(f"SELECT last_file_processed FROM {schema}.snapshot WHERE id = 1")
    result = cur.fetchone()

    cur.close()
    conn.close()

    return result[0] if result else None


def capture_data():
    # Créer le client S3/MinIO
    s3 = boto3.client(
        service_name=os.getenv("SERVICE_NAME"),
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        endpoint_url=os.getenv("ENDPOINT_URL")
    )

    # Bucket et répertoire local
    bucket_name = os.getenv("BUCKET_NAME")
    local_dir = os.path.join(os.getcwd(), "../../data")

    # Créer le répertoire 'data' à la racine du projet si besoin
    os.makedirs(local_dir, exist_ok=True)

    # Récupérer le dernier fichier traité
    last_processed = get_last_processed_file()
    print(f"Dernier fichier traité : {last_processed or 'Aucun (première exécution)'}")

    # Lister les objets du bucket
    response = s3.list_objects_v2(Bucket=bucket_name)
    all_files = [obj["Key"] for obj in response.get("Contents", [])]

    # Filtrer : ne garder que les fichiers .log plus récents que le snapshot
    if last_processed:
        new_files = [f for f in all_files if f.endswith(".log") and f > last_processed]
    else:
        new_files = [f for f in all_files if f.endswith(".log")]

    # Trier par ordre chronologique
    new_files.sort()

    print(f"Fichiers à traiter : {len(new_files)}")

    # Télécharger uniquement les nouveaux fichiers
    for file_key in new_files:
        local_path = os.path.join(local_dir, file_key)
        s3.download_file(bucket_name, file_key, local_path)
        print(f"  ✓ Téléchargé : {file_key}")

    return new_files


if __name__ == "__main__":
    capture_data()
