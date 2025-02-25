import os
import json
import boto3
import requests
import re
from base64 import b64encode

def validate_github_url(url):
    """Validate that the URL is a GitHub repository URL"""
    github_pattern = r'^https?://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+/?$'
    return re.match(github_pattern, url) is not None

def send_to_queue(event_body):
    """Send scan request to SQS queue"""
    sqs = boto3.client('sqs')
    queue_url = os.environ['SCAN_QUEUE_URL']
    
    # Create message with all necessary scan parameters
    message = {
        'repository_url': event_body['repository_url'],
        'branch': event_body.get('branch', 'main'),
        'language': event_body.get('language', 'auto'),
        'scan_path': event_body.get('scan_path', '.'),
        'scan_type': event_body.get('scan_type', 'full'),
        'priority': event_body.get('priority', 'normal'),
        'callback_url': event_body.get('callback_url', '')
    }
    
    # Send message to queue
    response = sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(message),
        MessageAttributes={
            'ScanType': {
                'DataType': 'String',
                'StringValue': message['scan_type']
            },
            'Priority': {
                'DataType': 'String',
                'StringValue': message['priority']
            }
        }
    )
    
    return response['MessageId']

def get_jenkins_token():
    """Retrieve Jenkins API token from Secrets Manager"""
    secret_arn = os.environ['JENKINS_API_TOKEN_SECRET_ARN']
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_arn)
    return json.loads(response['SecretString'])['token']

def trigger_jenkins_job(event_body):
    """Trigger Jenkins security scan job"""
    jenkins_url = os.environ['JENKINS_URL']
    token = get_jenkins_token()
    
    # Basic auth header
    auth = b64encode(f"admin:{token}".encode()).decode()
    headers = {
        'Authorization': f'Basic {auth}',
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    
    # Required parameters
    params = {
        'REPOSITORY_URL': event_body['repository_url'],
        'BRANCH': event_body.get('branch', 'main'),
        'LANGUAGE': event_body.get('language', 'auto'),
        'SCAN_PATH': event_body.get('scan_path', '.'),
        'SCAN_TYPE': event_body.get('scan_type', 'full')
    }
    
    # Build parameters string
    params_str = '&'.join([f'{k}={v}' for k, v in params.items()])
    
    # Trigger build with parameters
    job_url = f"{jenkins_url}/job/security-scan/buildWithParameters?{params_str}"
    response = requests.post(job_url, headers=headers)
    
    if response.status_code not in [200, 201]:
        raise Exception(f"Failed to trigger Jenkins job: {response.text}")
    
    # Get queue item location
    queue_url = response.headers.get('Location')
    return queue_url

def handler(event, context):
    try:
        # Parse request body
        body = json.loads(event['body'])
        
        # Validate required fields
        if 'repository_url' not in body:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'repository_url is required'})
            }
        
        # Validate GitHub URL
        if not validate_github_url(body['repository_url']):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid GitHub repository URL'})
            }
        
        # Determine if we should use queue or direct Jenkins trigger
        use_queue = os.environ.get('USE_QUEUE', 'true').lower() == 'true'
        
        if use_queue:
            # Send to SQS queue
            message_id = send_to_queue(body)
            return {
                'statusCode': 202,
                'body': json.dumps({
                    'message': 'Security scan request queued successfully',
                    'message_id': message_id
                }),
                'headers': {
                    'Content-Type': 'application/json'
                }
            }
        else:
            # Legacy direct Jenkins trigger
            queue_url = trigger_jenkins_job(body)
            return {
                'statusCode': 202,
                'body': json.dumps({
                    'message': 'Security scan triggered successfully',
                    'queue_url': queue_url
                }),
                'headers': {
                    'Content-Type': 'application/json'
                }
            }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {
                'Content-Type': 'application/json'
            }
        } 