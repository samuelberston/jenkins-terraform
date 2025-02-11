-- Enums for static types
CREATE TYPE scan_type AS ENUM ('codeql', 'dependency_check');
CREATE TYPE severity_level AS ENUM ('critical', 'high', 'medium', 'low', 'info');
CREATE TYPE scan_status AS ENUM ('pending', 'running', 'completed', 'failed');
CREATE TYPE vulnerability_status AS ENUM ('open', 'false_positive', 'fixed', 'accepted_risk', 'in_review');

-- Store information about scanned repositories
CREATE TABLE repositories (
    id SERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_scanned_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(url)
);

-- Store individual scan runs
CREATE TABLE scan_runs (
    id SERIAL PRIMARY KEY,
    repository_id INTEGER REFERENCES repositories(id),
    scan_type scan_type NOT NULL,
    branch TEXT NOT NULL,
    commit_hash TEXT,
    status scan_status NOT NULL DEFAULT 'pending',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    scan_path TEXT,
    language TEXT,
    error_message TEXT,
    CONSTRAINT valid_completion_time CHECK (completed_at IS NULL OR completed_at >= started_at)
);

-- Store found vulnerabilities
CREATE TABLE vulnerabilities (
    id SERIAL PRIMARY KEY,
    scan_run_id INTEGER REFERENCES scan_runs(id),
    tool_specific_id TEXT,
    title TEXT NOT NULL,
    description TEXT,
    severity severity_level NOT NULL,
    cvss_score DECIMAL(3,1),
    cwe_id TEXT,
    cve_id TEXT,
    file_path TEXT,
    line_number INTEGER,
    status vulnerability_status NOT NULL DEFAULT 'open',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Store AI analysis and recommendations
CREATE TABLE ai_analyses (
    id SERIAL PRIMARY KEY,
    vulnerability_id INTEGER REFERENCES vulnerabilities(id),
    false_positive_likelihood DECIMAL(3,2),
    priority_score DECIMAL(3,2),
    reasoning TEXT,
    remediation_suggestion TEXT,
    context_summary TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Store vulnerability suppression rules
CREATE TABLE suppression_rules (
    id SERIAL PRIMARY KEY,
    repository_id INTEGER REFERENCES repositories(id),
    rule_type TEXT NOT NULL,
    pattern TEXT NOT NULL,
    reason TEXT,
    created_by TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Store historical metrics
CREATE TABLE scan_metrics (
    id SERIAL PRIMARY KEY,
    scan_run_id INTEGER REFERENCES scan_runs(id),
    total_issues INTEGER NOT NULL DEFAULT 0,
    critical_count INTEGER NOT NULL DEFAULT 0,
    high_count INTEGER NOT NULL DEFAULT 0,
    medium_count INTEGER NOT NULL DEFAULT 0,
    low_count INTEGER NOT NULL DEFAULT 0,
    false_positive_count INTEGER NOT NULL DEFAULT 0,
    scan_duration_seconds INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for better query performance
CREATE INDEX idx_vulnerabilities_scan_run ON vulnerabilities(scan_run_id);
CREATE INDEX idx_vulnerabilities_status ON vulnerabilities(status);
CREATE INDEX idx_vulnerabilities_severity ON vulnerabilities(severity);
CREATE INDEX idx_scan_runs_repository ON scan_runs(repository_id);
CREATE INDEX idx_scan_runs_status ON scan_runs(status);

-- Trigger to update vulnerability timestamps
CREATE OR REPLACE FUNCTION update_vulnerability_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_vulnerability_timestamp
    BEFORE UPDATE ON vulnerabilities
    FOR EACH ROW
    EXECUTE FUNCTION update_vulnerability_timestamp();