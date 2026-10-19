
pipeline {
    agent any

    environment {
        MAVEN_OPTS = '--add-opens java.base/java.lang=ALL-UNNAMED'
    }

    stages {
        stage('Build with Maven') {
            steps {
                sh 'cd SampleWebApp && mvn clean install'
            }
        }

        stage('Test') {
            steps {
                sh 'cd SampleWebApp && mvn test'
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
                nexusArtifactUploader(
                    artifacts: [[
                        artifactId: 'SampleWebApp-1.0.0',
                        classifier: '',
                        file: 'SampleWebApp/target/SampleWebApp.war',
                        type: 'war'
                    ]],
                    credentialsId: 'nexuslogin',
                    groupId: 'com.sample.webproject',
                    nexusUrl: 'ec2-44-199-196-16.compute-1.amazonaws.com:8081',
                    nexusVersion: 'nexus3',
                    protocol: 'http',
                    repository: 'maven-snapshots',
                    version: '1.0-SNAPSHOT'
                )
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                deploy(
                    adapters: [
                        tomcat9(
                            alternativeDeploymentContext: '',
                            credentialsId: 'tompass',
                            path: '',
                            url: 'http://44.220.80.18:8080/'
                        )
                    ],
                    contextPath: 'monolithicapp',
                    war: 'SampleWebApp/target/SampleWebApp.war'
                )
            }
        }
    }
}
