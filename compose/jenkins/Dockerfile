FROM jenkins/jenkins:lts

USER root

ADD ./certs/ca.cert.pem /etc/ssl/certs/

RUN update-ca-certificates

USER jenkins

EXPOSE 8080
