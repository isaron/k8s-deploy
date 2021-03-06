FROM jenkins/inbound-agent:alpine

USER root

COPY ./bin/helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm \
    && mkdir -p /opt/kube /opt/helm/repository
COPY ./kube/kubeconf /opt/kube/config
COPY ./dockerfile/jenkins/slave/repositories.yaml /opt/helm/repository/repositories.yaml

ENV KUBECONFIG /opt/kube/config
ENV HELM_HOME /opt/helm

COPY ./certs/ca.cert.pem /etc/ssl/certs/ca.crt
RUN apk --update upgrade \
    && apk add --no-cache ca-certificates \
    && update-ca-certificates \
    && keytool -import -alias ssii.com -file /etc/ssl/certs/ca.crt -keystore "$JAVA_HOME/jre/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt \
    && echo "Asia/Chongqing" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && rm /var/cache/apk/* \
    # && helm init --client-only \
    && helm plugin install https://github.com/chartmuseum/helm-push \
    && helm repo add --username admin --password admin123 chartmuseum https://chartmuseum.ssii.com \
    # && helm repo add mirror http://172.30.80.33:8080/ \
    # && helm repo add bitnami https://charts.bitnami.com/bitnami \
    # && helm repo remove stable \
    # && helm repo update \
    && chown -R jenkins.jenkins /home/jenkins /opt/kube /opt/helm

USER jenkins
