FROM node:lts-alpine

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt
COPY ./certs/stevejenkins_com.crt /usr/local/share/ca-certificates/stevejenkins_com.crt

RUN apk add --no-cache ca-certificates \
    && update-ca-certificates \
    && echo "Asia/Chongqing" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && rm /var/cache/apk/*
