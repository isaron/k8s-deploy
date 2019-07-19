FROM openjdk:11-jre-slim

USER root

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt

RUN update-ca-certificates \
    && keytool -import -alias ssii.com -file /usr/local/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt \
    && echo "Asia/Chongqing" > /etc/timezone
