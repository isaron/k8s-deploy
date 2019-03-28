FROM openjdk:11-jre-slim

USER root

COPY ./certs/ca.cert.pem /usr/share/ca-certificates/ca.crt

RUN update-ca-certificates

RUN keytool -import -alias ssii.com -file /usr/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/jre/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt

RUN echo "Asia/Chongqing" > /etc/timezone
