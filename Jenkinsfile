pipeline {
    agent any
    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    parameters {
        string(name: 'PYTHON_PATH', defaultValue: 'C:/Users/86131/AppData/Local/Programs/Python/Python311/python.exe', description: 'Absolute path to Python on the Windows Jenkins machine')
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Python Environment') {
            steps {
                bat '"%PYTHON_PATH%" --version'
                bat '"%PYTHON_PATH%" -m venv .venv'
                bat '.venv\\Scripts\\python.exe -m pip --version'
            }
        }
        stage('Install Dependencies') {
            steps {
                bat '.venv\\Scripts\\python.exe -m pip install -r requirements.txt -r requirements-build.txt'
            }
        }
        stage('Lint') {
            steps { bat '.venv\\Scripts\\python.exe -m flake8 app.py tests' }
        }
        stage('Test') {
            steps {
                bat '.venv\\Scripts\\python.exe -m pytest tests --cov=app --cov-report=term-missing --cov-report=html --junitxml=test-results.xml'
            }
            post {
                always {
                    junit testResults: 'test-results.xml', allowEmptyResults: false
                    publishHTML(target: [allowMissing: false, alwaysLinkToLastBuild: true, keepAll: true, reportDir: 'htmlcov', reportFiles: 'index.html', reportName: 'Coverage Report'])
                }
            }
        }
        stage('Build') {
            steps {
                bat '.venv\\Scripts\\python.exe -m PyInstaller --noconfirm --onefile --name flask-demo app.py'
                archiveArtifacts artifacts: 'dist/flask-demo.exe', fingerprint: true
            }
        }
        stage('Deploy') {
            steps {
                withEnv(['JENKINS_NODE_COOKIE=flask-demo-local-service']) {
                    powershell './scripts/deploy.ps1'
                }
            }
        }
    }
    post {
        success { echo 'CI/CD passed. Local demo: http://127.0.0.1:5001/' }
        failure { echo 'CI/CD failed. Open the failing stage and Console Output.' }
    }
}
