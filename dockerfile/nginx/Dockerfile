FROM nginx:alpine

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt

RUN apk --update upgrade \
    && apk add --no-cache ca-certificates \
    && update-ca-certificates \
    && echo "Asia/Chongqing" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apk/*
