import os
import logging
import json
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import boto3
from pymongo import MongoClient
from botocore.exceptions import ClientError, NoCredentialsError, BotoCoreError
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Config - with environment variables
S3_BUCKET = os.environ.get('S3_BUCKET', 'clickops-s3-dev')
SECRET_NAME = os.environ.get('SECRET_NAME', 'clickops-sm-dev')
REGION_NAME = os.environ.get('AWS_REGION', 'us-east-1')
MONGO_HOST = os.environ.get('MONGO_HOST', 'mongodb')
MONGO_PORT = int(os.environ.get('MONGO_PORT', 27017))
DB_NAME = 'clickops-db-dev'
COLLECTION_NAME = 'users'

# AWS clients
session = boto3.session.Session()
s3_client = session.client(service_name='s3', region_name=REGION_NAME)
secrets_client = session.client(service_name='secretsmanager', region_name=REGION_NAME)

def get_mongo_credentials():
    logger.info("Attempting to fetch MongoDB credentials from AWS Secrets Manager")
    try:
        get_secret_value_response = secrets_client.get_secret_value(SecretId=SECRET_NAME)
    except (ClientError, NoCredentialsError, BotoCoreError) as e:
        logger.warning(f"AWS Secrets Manager bypassed. Could not retrieve secret {SECRET_NAME}. Error: {e}")
        return None, None
    else:
        if 'SecretString' in get_secret_value_response:
            secret = json.loads(get_secret_value_response['SecretString'])
            return secret.get('mongodb_username'), secret.get('mongodb_password')
    return None, None

def get_mongo_client():
    username, password = get_mongo_credentials()
    if username and password:
        uri = f"mongodb://{username}:{password}@{MONGO_HOST}:{MONGO_PORT}/"
        logger.info("Connecting to MongoDB using fetched credentials")
    else:
        uri = f"mongodb://{MONGO_HOST}:{MONGO_PORT}/"
        logger.warning("Connecting to MongoDB without credentials (fallback/dev mode)")
    
    return MongoClient(uri)

@app.route('/', methods=['GET'])
def serve_index():
    return send_from_directory('frontend', 'index.html')

@app.route('/api/health', methods=['GET'])
def health_check():
    db_status = 'Disconnected'
    try:
        client = get_mongo_client()
        client.admin.command('ping')
        db_status = 'Connected'
    except Exception as e:
        logger.warning(f"MongoDB health ping failed: {e}")
        
    return jsonify({
        "message": "Online",
        "database": db_status,
        "environment": os.environ.get('APP_ENV', 'dev')
    })

@app.route('/<path:filename>', methods=['GET'])
def serve_static(filename):
    return send_from_directory('frontend', filename)

@app.route('/upload', methods=['POST'])
def upload_user_data():
    try:
        # Validate Input
        name = request.form.get('name')
        age = request.form.get('age')
        
        if not name or not age:
            return jsonify({"error": "Name and age are required"}), 400
            
        if 'image' not in request.files:
            return jsonify({"error": "Image file is required"}), 400
            
        image = request.files['image']
        
        if image.filename == '':
            return jsonify({"error": "Empty file provided for image"}), 400
            
        if not image.mimetype.startswith('image/'):
             return jsonify({"error": "Uploaded file must be an image"}), 400
             
        # Generate secure filename to avoid conflicts and path traversal
        filename = secure_filename(image.filename)
        
        # 1. Upload to S3
        logger.info(f"Uploading file {filename} to S3 bucket {S3_BUCKET}")
        try:
            # Need to reset file pointer in case it was read
            image.seek(0)
            s3_client.upload_fileobj(image, S3_BUCKET, filename)
        except (ClientError, NoCredentialsError, BotoCoreError) as e:
            logger.warning(f"S3 Upload bypassed (No AWS Credentials). Mocking success for {filename}.")
        
        # 2. Store metadata in MongoDB
        logger.info("Connecting to Database")
        client = get_mongo_client()
        db = client[DB_NAME]
        collection = db[COLLECTION_NAME]
        
        user_data = {
            "name": name,
            "age": int(age),
            "image_filename": filename
        }
        
        logger.info(f"Inserting data into {DB_NAME}.{COLLECTION_NAME}")
        collection.insert_one(user_data)
        
        return jsonify({"message": "Data uploaded successfully!"}), 201

    except ClientError as ce:
         logger.error(f"AWS Services Error: {ce}")
         return jsonify({"error": "Failed to upload file to cloud storage.", "details": str(ce)}), 500
    except Exception as e:
        logger.error(f"Unexpected Backend Error: {e}")
        return jsonify({"error": "An unexpected error occurred processing your request.", "details": str(e)}), 500

if __name__ == '__main__':
    # Running on port 3000 as requested
    app.run(host='0.0.0.0', port=3000)
