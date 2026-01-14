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

    # Création des tables
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS {schema}.bronzeTable (
            logs VARCHAR2(255)
        );
    """)

    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    create_tables()
