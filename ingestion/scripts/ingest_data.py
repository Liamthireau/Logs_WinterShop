from dotenv import load_dotenv
import psycopg2
import os
import shutil
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


def update_snapshot(cursor, schema, last_file):
    """Met à jour la table snapshot avec le dernier fichier traité (INSERT ou UPDATE)."""
    cursor.execute(f"""
        INSERT INTO {schema}.snapshot (id, last_file_processed, updated_at)
        VALUES (1, %s, NOW())
        ON CONFLICT (id) DO UPDATE SET
            last_file_processed = EXCLUDED.last_file_processed,
            updated_at = NOW()
    """, (last_file,))


def clear_data_folder(data_dir):
    """Supprime tous les fichiers du dossier data/."""
    deleted_count = 0
    for file_path in data_dir.glob("*"):
        if file_path.is_file():
            file_path.unlink()
            deleted_count += 1
    return deleted_count


def ingest_logs():
    schema = os.getenv("DB_SCHEMA")
    cfg = get_db_config()

    # Dossier contenant les fichiers logs (relatif au fichier)
    data_dir = Path(__file__).parent.parent.parent / "data"

    conn = psycopg2.connect(**cfg)
    cur = conn.cursor()

    # Récupérer et trier les fichiers .log
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

    # Mettre à jour le snapshot avec le dernier fichier traité
    if last_file_name:
        update_snapshot(cur, schema, last_file_name)
        print(f"Snapshot mis à jour : {last_file_name}")

    conn.commit()
    cur.close()
    conn.close()

    print(f"Total lignes ingérées : {total_lines}")

    # Vider le dossier data/ après succès
    deleted = clear_data_folder(data_dir)
    print(f"Dossier data/ nettoyé : {deleted} fichier(s) supprimé(s)")


if __name__ == "__main__":
    ingest_logs()