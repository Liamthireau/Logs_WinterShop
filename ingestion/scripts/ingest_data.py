from dotenv import load_dotenv
import psycopg2
import os
from pathlib import Path

# Chargement des variables d'environnement
load_dotenv()

def get_db_config():
    return {
        "host": os.getenv("DB_HOST"),
        "port": os.getenv("DB_PORT"),
        "dbname": os.getenv("DB_NAME"),
        "user": os.getenv("DB_USER"),
        "password": os.getenv("DB_PASSWORD"),
    }

def ingest_logs():
    schema = os.getenv("DB_SCHEMA")
    cfg = get_db_config()
    
    # Dossier contenant les fichiers logs (relatif au fichier)
    data_dir = Path(__file__).parent.parent.parent / "data"

    conn = psycopg2.connect(**cfg)
    cur = conn.cursor()

    # Parcourir tous les fichiers .log du dossier data
    log_files = list(data_dir.glob("*.log"))
    print(f"Fichiers trouvés : {len(log_files)}")

    total_lines = 0
    for log_file in log_files:
        print(f"Traitement de : {log_file.name}")

        with open(log_file, "r", encoding="utf-8") as f:
            for line in f:
                line_content = line.strip()
                if line_content:
                    cur.execute(
                        f"INSERT INTO {schema}.bronzetable (logs) VALUES (%s)",
                        (line_content,)
                    )
                    total_lines += 1

    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    ingest_logs()