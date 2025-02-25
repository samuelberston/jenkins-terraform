#!/usr/bin/env python3
import os
import json
import time
import boto3
import subprocess
import logging
import tempfile
import shutil
import uuid
import requests
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("/var/log/security_scanner/worker.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("security_scanner")

# Configuration
QUEUE_URL = os.environ.get('SCAN_QUEUE_URL')
GITHUB_TOKEN_SECRET_ARN = os.environ.get('GITHUB_TOKEN_SECRET_ARN')
DB_CREDENTIALS_SECRET_ARN = os.environ.get('DB_CREDENTIALS_SECRET_ARN')
RESULTS_DIR = "/var/lib/security_scanner/results"
SCAN_TIMEOUT = 3600  # 1 hour timeout for scans

# Ensure directories exist
os.makedirs(RESULTS_DIR, exist_ok=True)
os.makedirs("/var/log/security_scanner", exist_ok=True)

# Initialize AWS clients
sqs = boto3.client('sqs')
secretsmanager = boto3.client('secretsmanager')

def get_github_token():
    """Retrieve GitHub token from AWS Secrets Manager"""
    try:
        response = secretsmanager.get_secret_value(SecretId=GITHUB_TOKEN_SECRET_ARN)
        secret = json.loads(response['SecretString'])
        return secret['token']
    except Exception as e:
        logger.error(f"Error retrieving GitHub token: {e}")
        return None

def get_db_credentials():
    """Retrieve database credentials from AWS Secrets Manager"""
    try:
        response = secretsmanager.get_secret_value(SecretId=DB_CREDENTIALS_SECRET_ARN)
        return json.loads(response['SecretString'])
    except Exception as e:
        logger.error(f"Error retrieving DB credentials: {e}")
        return None

def clone_repository(repo_url, branch, work_dir):
    """Clone a GitHub repository to the specified directory"""
    github_token = get_github_token()
    if not github_token:
        raise Exception("Failed to retrieve GitHub token")
    
    # Format URL with token for private repos
    auth_url = repo_url.replace('https://', f'https://{github_token}@')
    
    try:
        logger.info(f"Cloning repository: {repo_url}, branch: {branch}")
        result = subprocess.run(
            ['git', 'clone', '--branch', branch, '--single-branch', '--depth', '1', auth_url, work_dir],
            capture_output=True,
            text=True,
            check=True
        )
        logger.info("Repository cloned successfully")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Git clone failed: {e.stderr}")
        return False

def run_codeql_scan(work_dir, language, scan_path, scan_id):
    """Run CodeQL analysis on the repository"""
    results_file = os.path.join(RESULTS_DIR, f"codeql-results-{scan_id}.sarif")
    
    try:
        # Create CodeQL database
        db_path = os.path.join(work_dir, "codeql_db")
        
        # Determine language if set to auto
        if language == "auto":
            # Try to detect language based on files
            if os.path.exists(os.path.join(work_dir, scan_path, "pom.xml")) or \
               os.path.exists(os.path.join(work_dir, scan_path, "build.gradle")):
                language = "java"
            elif os.path.exists(os.path.join(work_dir, scan_path, "package.json")):
                language = "javascript"
            elif os.path.exists(os.path.join(work_dir, scan_path, "requirements.txt")) or \
                 os.path.exists(os.path.join(work_dir, scan_path, "setup.py")):
                language = "python"
            elif os.path.exists(os.path.join(work_dir, scan_path, "Cargo.toml")):
                language = "rust"
            elif os.path.exists(os.path.join(work_dir, scan_path, "go.mod")):
                language = "go"
            else:
                # Default to javascript if we can't determine
                language = "javascript"
        
        logger.info(f"Creating CodeQL database for language: {language}")
        subprocess.run(
            ['codeql', 'database', 'create', db_path, 
             '--language', language, 
             '--source-root', os.path.join(work_dir, scan_path)],
            check=True
        )
        
        # Analyze the database
        logger.info("Analyzing CodeQL database")
        subprocess.run(
            ['codeql', 'database', 'analyze', db_path,
             '--format=sarif-latest', 
             '--output', results_file],
            check=True
        )
        
        logger.info(f"CodeQL analysis completed. Results saved to {results_file}")
        return results_file
    except subprocess.CalledProcessError as e:
        logger.error(f"CodeQL analysis failed: {e}")
        return None

def run_dependency_check(work_dir, scan_path, scan_id):
    """Run OWASP Dependency Check on the repository"""
    results_file = os.path.join(RESULTS_DIR, f"dependency-check-results-{scan_id}.xml")
    
    try:
        logger.info("Running OWASP Dependency Check")
        subprocess.run(
            ['dependency-check', 
             '--scan', os.path.join(work_dir, scan_path),
             '--format', 'XML',
             '--out', results_file,
             '--enableExperimental'],
            check=True
        )
        
        logger.info(f"Dependency Check completed. Results saved to {results_file}")
        return results_file
    except subprocess.CalledProcessError as e:
        logger.error(f"Dependency Check failed: {e}")
        return None

def store_results_in_db(scan_id, repo_url, branch, codeql_results, dependency_results):
    """Store scan results in the database"""
    db_creds = get_db_credentials()
    if not db_creds:
        logger.error("Failed to retrieve database credentials")
        return False
    
    # Here you would implement the database storage logic
    # This is a placeholder - you'll need to implement the actual DB connection
    logger.info(f"Storing results for scan {scan_id} in database")
    
    # For now, we'll just log that we would store the results
    logger.info(f"Would store: scan_id={scan_id}, repo={repo_url}, branch={branch}")
    logger.info(f"CodeQL results: {codeql_results}")
    logger.info(f"Dependency Check results: {dependency_results}")
    
    return True

def send_callback(callback_url, scan_id, status, results=None):
    """Send results to callback URL if provided"""
    if not callback_url:
        return
    
    payload = {
        "scan_id": scan_id,
        "status": status,
        "completed_at": datetime.utcnow().isoformat(),
        "results": results or {}
    }
    
    try:
        response = requests.post(
            callback_url,
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        logger.info(f"Callback sent to {callback_url}, status: {response.status_code}")
    except Exception as e:
        logger.error(f"Failed to send callback: {e}")

def process_message(message):
    """Process a scan request message from SQS"""
    try:
        body = json.loads(message['Body'])
        
        # Extract scan parameters
        repo_url = body['repository_url']
        branch = body.get('branch', 'main')
        language = body.get('language', 'auto')
        scan_path = body.get('scan_path', '.')
        scan_type = body.get('scan_type', 'full')
        callback_url = body.get('callback_url', '')
        
        # Generate a unique scan ID
        scan_id = str(uuid.uuid4())
        
        logger.info(f"Processing scan request {scan_id} for {repo_url}, branch: {branch}")
        
        # Create temporary directory for the repository
        work_dir = tempfile.mkdtemp(prefix="security_scan_")
        
        try:
            # Clone the repository
            if not clone_repository(repo_url, branch, work_dir):
                logger.error(f"Failed to clone repository: {repo_url}")
                send_callback(callback_url, scan_id, "failed", {"error": "Repository clone failed"})
                return
            
            results = {}
            
            # Run CodeQL scan
            codeql_results = run_codeql_scan(work_dir, language, scan_path, scan_id)
            if codeql_results:
                results['codeql'] = codeql_results
            
            # Run Dependency Check if full scan requested
            if scan_type == 'full':
                dependency_results = run_dependency_check(work_dir, scan_path, scan_id)
                if dependency_results:
                    results['dependency_check'] = dependency_results
            
            # Store results in database
            store_results_in_db(scan_id, repo_url, branch, 
                               codeql_results, 
                               results.get('dependency_check'))
            
            # Send callback if URL provided
            send_callback(callback_url, scan_id, "completed", {
                "codeql_results": codeql_results is not None,
                "dependency_check_results": 'dependency_check' in results
            })
            
            logger.info(f"Scan {scan_id} completed successfully")
            
        finally:
            # Clean up temporary directory
            shutil.rmtree(work_dir, ignore_errors=True)
        
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        # Try to send callback if we have enough information
        try:
            if 'body' in locals() and 'callback_url' in body:
                scan_id = locals().get('scan_id', str(uuid.uuid4()))
                send_callback(body['callback_url'], scan_id, "failed", {"error": str(e)})
        except:
            pass

def main():
    """Main worker loop to poll SQS queue and process messages"""
    logger.info("Security Scanner worker starting")
    
    while True:
        try:
            # Receive message from SQS queue
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20,
                VisibilityTimeout=SCAN_TIMEOUT
            )
            
            messages = response.get('Messages', [])
            
            if not messages:
                logger.debug("No messages received, continuing to poll")
                continue
            
            for message in messages:
                logger.info(f"Received message: {message['MessageId']}")
                
                try:
                    # Process the message
                    process_message(message)
                    
                    # Delete the message from the queue
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=message['ReceiptHandle']
                    )
                    logger.info(f"Message {message['MessageId']} processed and deleted")
                    
                except Exception as e:
                    logger.error(f"Failed to process message {message['MessageId']}: {e}", exc_info=True)
                    # Message will return to the queue after visibility timeout
        
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
            time.sleep(30)  # Wait before retrying

if __name__ == "__main__":
    main()