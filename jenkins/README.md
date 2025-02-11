# Security Scanning Pipeline

This Jenkins pipeline setup provides automated security scanning capabilities through CodeQL and OWASP Dependency Check.

## Available Jobs

### 1. Security Scan (`security-scan/Jenkinsfile`)
Main orchestrator pipeline that runs both CodeQL and Dependency Check in parallel.

**Parameters:**
- `REPOSITORY_URL`: Git repository to analyze
- `BRANCH`: Branch to analyze (default: main)
- `LANGUAGE`: Programming language for CodeQL (java/python/javascript/cpp)
- `SCAN_PATH`: Path to scan for dependencies (default: .)

### 2. CodeQL Analysis (`codeql-analysis/Jenkinsfile`)
Performs static code analysis using GitHub's CodeQL engine.

**Parameters:**
- `REPOSITORY_URL`: Git repository to analyze
- `BRANCH`: Branch to analyze (default: main)
- `LANGUAGE`: Programming language to analyze

### 3. Dependency Check (`dependency-check/Jenkinsfile`)
Scans project dependencies for known vulnerabilities using OWASP Dependency Check.

**Parameters:**
- `REPOSITORY_URL`: Git repository to analyze
- `BRANCH`: Branch to analyze (default: main)
- `SCAN_PATH`: Path to scan (default: .)
- `SUPPRESSION_FILE`: Optional XML file for suppressing false positives

## Requirements

- Jenkins agent with label `security-scanner-agent`
- CodeQL CLI installed at `/usr/local/bin/codeql`
- OWASP Dependency Check installed at `/usr/share/dependency-check`
- Required Jenkins plugins:
  - HTML Publisher
  - Warnings Next Generation
  - Git

## Quality Gates

- CodeQL: Build becomes unstable if any security issues are found
- Dependency Check: Build becomes unstable if vulnerabilities with CVSS score ≥ 7 are found

## Reports

All jobs generate and archive detailed reports:
- CodeQL: SARIF format
- Dependency Check: HTML, JSON, and SARIF formats 