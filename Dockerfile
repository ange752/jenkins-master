FROM jenkins/jenkins:2.114-alpine

ENV ROOT_URL=http://localhost:8083/jenkins
ENV ROOT_EMAIL=cloud@qaprosoft.com
ENV ADMIN_USER=admin
ENV ADMIN_PASS=qaprosoft
ENV SMTP_HOST=smtp.gmail.com
ENV SMTP_USER=cloud@qaprosoft.com
ENV SMTP_PASS=CHANGEME
ENV JENKINS_PIPELINE_GIT_URL=git@github.com:qaprosoft/qps-pipeline.git
ENV JENKINS_PIPELINE_GIT_BRANCH=master
ENV JENKINS_OPTS="--prefix=/jenkins --httpPort=-1 --httpsPort=8083 --httpsKeyStore=/var/jenkins_home/keystore.jks --httpsKeyStorePassword=password"
ENV CARINA_CORE_VERSION=LATEST
ENV CORE_LOG_LEVEL=INFO
ENV SELENIUM_HOST=http://localhost:4444/wd/hub
ENV ZAFIRA_ACCESS_TOKEN=eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIyIiwicGFzc3dvcmQiOiJhaTk1Q0JFUmN2MEw4WHZERWozMzV3dkxhK1AxMU50ViIsImV4cCI6MTMwMzYxNjcxMTk2fQ.5S1SA9KP9wXTR9_c-fW9j2fj0e8-3uesDWRv4MfYhrF5O4zSQ2TtzmRpmFjrnroYJ3RTWIf5yUAVJEWTRkKYAw
ENV ZAFIRA_BASE_CONFIG="-Dzafira_enabled=true -Dzafira_rerun_failures=\$rerun_failures -Dzafira_service_url=\$ZAFIRA_SERVICE_URL -Dgit_branch=\$branch -Dgit_commit=\$GIT_COMMIT -Dgit_url=\$repository -Dci_user_id=\$BUILD_USER_ID -Dci_user_first_name=\$BUILD_USER_FIRST_NAME -Dci_user_last_name=\$BUILD_USER_LAST_NAME -Dci_user_email=\$BUILD_USER_EMAIL -Dzafira_access_token=\$ZAFIRA_ACCESS_TOKEN"
ENV ZAFIRA_SERVICE_URL=https://localhost:8080/zafira-ws
ENV JACOCO_BUCKET=jacoco.qaprosoft.com
ENV JACOCO_ENABLE=true
ENV AWS_KEY=AKIAIF43YTFM7RWG7EVQ
ENV AWS_SECRET=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
ENV GITHUB_API_URL=https://api.\$GITHUB_HOST/
ENV GITHUB_HOST=github.com
ENV GITHUB_HTML_URL=https://\$GITHUB_HOST/\$GITHUB_ORGANIZATION
ENV GITHUB_OAUTH_TOKEN=7986abef9d29860448dd7ab969aa42c4f2054aea
ENV GITHUB_ORGANIZATION=qaprosoft
ENV GITHUB_SSH_URL=git@\$GITHUB_HOST:\$GITHUB_ORGANIZATION
ENV JOB_MAX_RUN_TIME=60

USER root

# Install Git

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh


# Install Apache Maven

ARG MAVEN_VERSION=3.5.2
ARG USER_HOME_DIR="/root"
ARG SHA=707b1f6e390a65bde4af4cdaf2a24d45fc19a6ded00fff02e91626e3e42ceaff
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha256sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

COPY resources/scripts/mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
COPY resources/configs/settings-docker.xml /usr/share/maven/ref/

VOLUME "$USER_HOME_DIR/.m2"

RUN chown -R jenkins "$USER_HOME_DIR" /usr/share/maven /usr/share/maven/ref
RUN chmod a+w /etc/ssl/certs/java/cacerts

RUN /usr/local/bin/mvn-entrypoint.sh

# Initialize Jenkins

USER jenkins

COPY resources/init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/
COPY resources/jobs/ /usr/share/jenkins/ref/jobs/

# Configure plugins

COPY resources/configs/plugins.txt /usr/share/jenkins/ref/
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/ref/plugins.txt

COPY resources/configs/jp.ikedam.jenkins.plugins.extensible_choice_parameter.GlobalTextareaChoiceListProvider.xml /usr/share/jenkins/ref/
COPY resources/configs/org.jenkinsci.plugins.workflow.libs.GlobalLibraries.xml /usr/share/jenkins/ref/

# replace SMTP_HOST, SMTP_USER and SMTP_PSWD with values from env variables
RUN sed -i "s/SMTP_HOST/$SMTP_HOST/g" resources/configs/hudson.plugins.emailext.ExtendedEmailPublisher.xml
RUN sed -i "s/SMTP_HOST/$SMTP_HOST/g" resources/configs/hudson.tasks.Mailer.xml

RUN sed -i "s/SMTP_USER/$SMTP_USER/#g" resources/configs/hudson.plugins.emailext.ExtendedEmailPublisher.xml
RUN sed -i "s/SMTP_USER/$SMTP_USER/#g" resources/configs/hudson.tasks.Mailer.xml

RUN sed -i "s/SMTP_PASS/$SMTP_PASS/#g" resources/configs/hudson.plugins.emailext.ExtendedEmailPublisher.xml
RUN sed -i "s/SMTP_PASS/$SMTP_PASS/#g" resources/configs/hudson.tasks.Mailer.xml

COPY resources/configs/hudson.plugins.emailext.ExtendedEmailPublisher.xml /usr/share/jenkins/ref/
COPY resources/configs/hudson.tasks.Mailer.xml /usr/share/jenkins/ref/