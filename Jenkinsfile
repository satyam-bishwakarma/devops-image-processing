pipeline {
    agent { label 'docker' }
    environment {
        GHCR_IMAGE = 'ghcr.io/satyam-bishwakarma/devops-image-processing'
    }
    options {
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }
    stages {
        stage('Build image') {
            steps {
                sh '''
                    docker build --build-arg APP_VERSION="$(git rev-parse HEAD)" -t "image-processing-ci:$BUILD_TAG" .
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
        stage('Publish tested image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'ghcr-image-processing-publish', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    sh '''
                        set +x
                        commit=$(git rev-parse HEAD)
                        test "$commit" = "$(git rev-parse refs/remotes/origin/main)"
                        DOCKER_CONFIG=$(mktemp -d)
                        export DOCKER_CONFIG
                        trap 'rm -rf "$DOCKER_CONFIG"' EXIT
                        printf '%s\n' "$GHCR_TOKEN" | docker login ghcr.io --username "$GHCR_USER" --password-stdin
                        image="$GHCR_IMAGE:$commit"
                        docker tag "image-processing-ci:$BUILD_TAG" "$image"
                        docker push "$image"
                        docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$image" | awk -v prefix="$GHCR_IMAGE@" 'index($0, prefix) == 1 { print; exit }' > image-reference.txt
                        test -s image-reference.txt
                        cat image-reference.txt
                    '''
                }
                archiveArtifacts artifacts: 'image-reference.txt', fingerprint: true
            }
        }
    }
    post {
        always {
            sh '''
                docker rm -f "$BUILD_TAG" 2>/dev/null || true
                if commit=$(git rev-parse HEAD 2>/dev/null); then
                    docker image rm "$GHCR_IMAGE:$commit" 2>/dev/null || true
                fi
                docker image rm "image-processing-ci:$BUILD_TAG" 2>/dev/null || true
            '''
        }
    }
}
