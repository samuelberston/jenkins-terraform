#!/bin/bash
set -e

# Load environment variables from AWS Secrets Manager
DB_CREDS=$(aws secretsmanager get-secret-value --secret-id ${DB_CREDENTIALS_SECRET_ARN} --query SecretString --output text)
export DB_HOST=$(echo $DB_CREDS | jq -r .host)
export DB_NAME=$(echo $DB_CREDS | jq -r .dbname)
export DB_USERNAME=$(echo $DB_CREDS | jq -r .username)
export DB_PASSWORD=$(echo $DB_CREDS | jq -r .password)

# Run Flyway migrations
flyway -configFiles=flyway.conf migrate