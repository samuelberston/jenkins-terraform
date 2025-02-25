# SQS Queue Processor

This job polls the SQS queue for security scan requests and triggers the appropriate scan jobs.

## Configuration

- Runs every 5 minutes via cron trigger
- Processes up to 10 messages per run
- Sets visibility timeout to 5 minutes to prevent duplicate processing
- Requires AWS credentials with SQS permissions

## Process

1. Polls the SQS queue for messages
2. For each message:
   - Parses the request parameters
   - Triggers the api-triggered-scan job with the appropriate parameters
   - Deletes the message from the queue upon successful processing
   - If processing fails, the message returns to the queue after the visibility timeout

## Required Credentials

- `sqs-queue-url`: Jenkins credential containing the SQS queue URL