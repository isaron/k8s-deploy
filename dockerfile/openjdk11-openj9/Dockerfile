FROM adoptopenjdk/openjdk11-openj9:alpine-jre

USER root

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt

RUN apk --update upgrade \
    && apk add --no-cache ca-certificates \
    && update-ca-certificates \
    && keytool -import -alias ssii.com -file /usr/local/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt \
    && echo "Asia/Chongqing" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apk/*
