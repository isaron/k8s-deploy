FROM jenkins/jenkins:lts-alpine

USER root

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt
COPY ./certs/stevejenkins_com.crt /usr/local/share/ca-certificates/stevejenkins_com.crt

RUN apk add --no-cache ca-certificates \
    && update-ca-certificates \
    && keytool -import -alias ssii.com -file /usr/local/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/jre/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt \
    && keytool -import -alias stevejenkins.com -file /usr/local/share/ca-certificates/stevejenkins_com.crt -keystore "$JAVA_HOME/jre/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt \
    && echo "Asia/Chongqing" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && rm /var/cache/apk/*

EXPOSE 8080

EXPOSE 50000

USER jenkins
