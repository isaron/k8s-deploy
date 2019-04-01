FROM jenkins/jenkins:lts

USER root

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt

RUN update-ca-certificates

RUN keytool -import -alias ssii.com -file /usr/local/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/jre/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt

RUN echo "Asia/Chongqing" > /etc/timezone

USER jenkins

EXPOSE 8080

EXPOSE 50000
