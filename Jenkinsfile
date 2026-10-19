
pipeline {
    agent any

    environment {
        MAVEN_OPTS = '--add-opens java.base/java.lang=ALL-UNNAMED'
    }

    stages {

        stage('Build with Maven') {
            steps {
                dir('SampleWebApp') {
                    sh 'mvn clean package'
                }
            }
        }

        stage('Test') {
            steps {
                dir('SampleWebApp') {
                    sh 'mvn test'
                }
            }
        }

        stage('Code Quality Scan') {
            steps {
                withSonarQubeEnv('sonar_scanner') {
                    sh 'mvn -f SampleWebApp/pom.xml sonar:sonar'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Push to Nexus') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'nexuslogin',
                        usernameVariable: 'NEXUS_USERNAME',
                        passwordVariable: 'NEXUS_PASSWORD'
                    )
                ]) {
                    dir('SampleWebApp') {
                        sh 'mvn deploy'
                    }
                }
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                deploy adapters: [
                    tomcat9(
                        alternativeDeploymentContext: '',
                        credentialsId: 'tompass',
                        path: '',
                        url: 'http://44.220.80.18:8080/'
                    )
                ],
                contextPath: 'monolithicapp',
                war: 'SampleWebApp/target/SampleWebApp.war'
            }
        }
    }
}
