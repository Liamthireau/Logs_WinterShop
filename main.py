#Lister les fichiers d'un bucket type S3 (ici MinIO)

import boto3
from boto3.session import Session

# Créer une session boto3 avec les paramètres MinIO
session = Session(
    aws_access_key_id="studentSDV",
    aws_secret_access_key="coucou44",
)

# Créer un client S3 pointant vers MinIO
s3 = session.client(
    service_name="s3",
    endpoint_url= "http://51.77.215.42:9010",
)

# Exemple : Lister les objets dans un bucket

response = s3.list_objects_v2(Bucket="wintershoplogs")
for obj in response["Contents"]:
    print(obj["Key"])