FROM jenkins/jenkins:lts

USER root

ADD ./certs/ca.cert.pem /usr/share/ca-certificates/ca.crt

RUN update-ca-certificates

USER jenkins

EXPOSE 8080
