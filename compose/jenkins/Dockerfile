FROM jenkins

ADD executors.groovy /usr/share/jenkins/ref/init.groovy.d/executors.groovy

USER root

RUN apt-get update

RUN curl -sSL https://get.docker.com/ | sh

RUN usermod -a -G docker root

RUN usermod -a -G docker jenkins

RUN apt-get install -y sudo

RUN chmod u+w /etc/sudoers

RUN echo 'jenkins ALL=(ALL)       NOPASSWD: ALL'>>/etc/sudoers

RUN chmod u-w /etc/sudoers

RUN apt-get install -y vim

ADD dind /usr/local/bin/

RUN chmod +x /usr/local/bin/dind

ADD dockerd-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/dockerd-entrypoint.sh

ADD log.properties /var/jenkins_home/

ENV JAVA_OPTS="-Djava.util.logging.config.file=/var/jenkins_home/log.properties"

RUN mkdir -p /etc/docker/certs.d/registry.test.com\:5000/

ADD domain.crt /etc/docker/certs.d/registry.test.com\:5000/

VOLUME /var/lib/docker

EXPOSE 2375
