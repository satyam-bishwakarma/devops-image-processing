pipeline {
    agent { label 'docker' }
    options {
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }
    stages {
        stage('Build image') {
            steps {
                sh '''
                    docker build --build-arg APP_VERSION="$(git rev-parse HEAD)" \
                      -t "image-processing-ci:$BUILD_TAG" .
                '''
            }
        }
        stage('Smoke test') {
            steps {
                sh '''
                    docker run -d --name "$BUILD_TAG" "image-processing-ci:$BUILD_TAG"
                    docker exec -i "$BUILD_TAG" python - < scripts/smoke.py
                '''
            }
        }
    }
    post {
        always {
            sh '''
                docker rm -f "$BUILD_TAG" 2>/dev/null || true
                docker image rm "image-processing-ci:$BUILD_TAG" 2>/dev/null || true
            '''
        }
    }
}
