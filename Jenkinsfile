pipeline {
    agent { label 'docker' }
    environment {
        GHCR_IMAGE = 'ghcr.io/satyam-bishwakarma/devops-image-processing'
        SONAR_SCANNER_IMAGE = 'sonarsource/sonar-scanner-cli:12.4.0.4321_8.4.0'
        TRIVY_IMAGE = 'aquasec/trivy:0.76.2'
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
        stage('SonarQube analysis and quality gate') {
            steps {
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE', catchInterruptions: false) {
                    withCredentials([string(credentialsId: 'image-processing-sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            set +x
                            docker run --rm --user 0 --cap-drop ALL --security-opt no-new-privileges \\
                                --network image-processing-security \\
                                -e SONAR_TOKEN -e SONAR_HOST_URL=http://sonarqube:9000 \\
                                -e SONAR_USER_HOME=/tmp/sonar-home \\
                                -v "$WORKSPACE:/usr/src" -w /usr/src \\
                                "$SONAR_SCANNER_IMAGE" \\
                                -Dsonar.projectKey=image-processing \\
                                -Dsonar.sources=backend,frontend/src,infra,deploy,scripts \\
                                -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=300
                        '''
                    }
                }
            }
        }
        stage('Trivy image security scan') {
            steps {
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE', catchInterruptions: false) {
                    sh '''
                        scan_dir=$(mktemp -d)
                        trap 'rm -rf "$scan_dir"' EXIT
                        rm -f trivy-image-report.txt
                        docker save -o "$scan_dir/image.tar" "image-processing-ci:$BUILD_TAG"
                        status=0
                        docker run --rm --cap-drop ALL --security-opt no-new-privileges \\
                            -v "$scan_dir:/scan:ro" \\
                            -v image-processing-trivy-cache:/root/.cache/trivy \\
                            "$TRIVY_IMAGE" image --input /scan/image.tar \\
                            --scanners vuln,secret --severity HIGH,CRITICAL --exit-code 1 \\
                            --timeout 5m --no-progress > trivy-image-report.txt 2>&1 || status=$?
                        cat trivy-image-report.txt
                        exit "$status"
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-image-report.txt', allowEmptyArchive: true
                }
            }
        }
        stage('Publish tested image') {
            when {
                expression { currentBuild.currentResult == 'SUCCESS' }
            }
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
