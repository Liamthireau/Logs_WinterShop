# Télécharger un fichier

bucket_name = "wintershoplogs"
file_key = "access_2026-01-14_09-00-01.log"
local_path = "access_2026-01-14_09-00-01.log"
s3.download_file(bucket_name, file_key, local_path)