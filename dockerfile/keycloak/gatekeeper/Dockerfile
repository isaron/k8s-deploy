FROM alpine:3.8

ENV NAME keycloak-gatekeeper
ENV KEYCLOAK_VERSION 6.0.1
ENV GOOS linux
ENV GOARCH amd64

LABEL Name=keycloak-gatekeeper \
      Release=https://github.com/keycloak/keycloak-gatekeeper \
      Url=https://github.com/keycloak/keycloak-gatekeeper \
      Help=https://issues.jboss.org/projects/KEYCLOAK

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt

RUN apk add --no-cache ca-certificates curl tar && update-ca-certificates && echo "Asia/Chongqing" > /etc/timezone

WORKDIR "/opt"

RUN curl -fssL "https://downloads.jboss.org/keycloak/$KEYCLOAK_VERSION/gatekeeper/$NAME-$GOOS-$GOARCH.tar.gz" | tar -xz && chmod +x /opt/$NAME

RUN apk del curl tar

ENTRYPOINT [ "/opt/keycloak-gatekeeper" ]