from dotenv import load_dotenv
import psycopg2
import os

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

def create_tables():
    schema = os.getenv("DB_SCHEMA")
    cfg = get_db_config()

    conn = psycopg2.connect(**cfg)
    cur = conn.cursor()

    # Création de la table bronze (données brutes uniquement)
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {schema}.bronzetable (
            logs TEXT
        );
    """)

    # Création de la table snapshot (une seule ligne toujours)
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {schema}.snapshot (
            id INTEGER PRIMARY KEY DEFAULT 1,
            last_file_processed VARCHAR(255),
            updated_at TIMESTAMP DEFAULT NOW(),
            CONSTRAINT single_row CHECK (id = 1)
        );
    """)

    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    create_tables()