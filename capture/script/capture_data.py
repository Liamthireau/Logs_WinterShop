import os
from dotenv import load_dotenv
import boto3

# Charger les variables d'environnement
load_dotenv()

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

# Lister les objets et les télécharger
response = s3.list_objects_v2(Bucket=bucket_name)
for obj in response.get("Contents", []):
    file_key = obj["Key"]
    local_path = os.path.join(local_dir, file_key)

    s3.download_file(bucket_name, file_key, local_path)
