pipeline {
    agent any
    
    environment {
        GITHUB_REPO = 'your-repo-url'
    }
    
    stages {
        stage('Checkout') {
            steps {
                // Checkout your code
                git branch: 'main', url: env.GITHUB_REPO
            }
        }
        
        stage('CodeQL Analysis') {
            steps {
                // Initialize CodeQL
                sh """
                    codeql database create db --language=javascript --source-root .
                    codeql database analyze db javascript-security-and-quality.qls --format=sarif-latest --output=results.sarif
                """
            }
        }
        
        stage('OWASP Dependency Check') {
            steps {
                // Run OWASP Dependency Check
                dependencyCheck additionalArguments: '''
                    --scan ./ 
                    --format "HTML" 
                    --format "JSON"
                    --prettyPrint''', 
                odcInstallation: 'OWASP-Dependency-Check'
            }
        }
        
        stage('Build') {
            steps {
                // Add your build steps here
                sh 'echo "Add your build commands here"'
            }
        }
    }
    
    post {
        always {
            // Publish OWASP report
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            
            // Archive CodeQL results
            archiveArtifacts artifacts: 'results.sarif', fingerprint: true
        }
    }
}