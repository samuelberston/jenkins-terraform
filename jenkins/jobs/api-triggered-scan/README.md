# API-Triggered Security Scan

This job processes security scan requests that come from the API or SQS queue.

## Parameters

- `REPOSITORY_URL`: GitHub repository URL to analyze
- `BRANCH`: Branch to analyze (default: main)
- `LANGUAGE`: Programming language for CodeQL (auto/java/python/javascript/cpp/go/ruby)
- `SCAN_PATH`: Path to scan for dependencies (default: .)
- `SCAN_TYPE`: Type of scan to perform (full/codeql-only/dependency-only)
- `CALLBACK_URL`: URL to call with results (optional)
- `MESSAGE_ID`: SQS message ID (for tracking)

## Features

- Validates GitHub repository URL and accessibility
- Auto-detects programming language when set to 'auto'
- Runs CodeQL and/or Dependency Check based on scan type
- Sends results to callback URL if provided
- Handles failures gracefully with proper error reporting

## Usage

This job is typically triggered by the SQS Queue Processor, but can also be triggered manually or via the Jenkins API. 