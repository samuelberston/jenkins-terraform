import os
import json
import boto3
import requests
from base64 import b64encode

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
        'LANGUAGE': event_body.get('language', 'javascript'),
        'SCAN_PATH': event_body.get('scan_path', '.')
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
        
        # Trigger Jenkins job
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