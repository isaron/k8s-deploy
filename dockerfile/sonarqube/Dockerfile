FROM sonarqube:7.6-community

USER root

COPY sonar.properties /opt/sonarqube/conf/

RUN chown sonarqube:sonarqube /opt/sonarqube/conf/sonar.properties

COPY ./certs/ca.cert.pem /usr/share/ca-certificates/ca.crt

RUN update-ca-certificates

RUN keytool -import -alias ssii.com -file /usr/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/jre/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt

RUN echo "Asia/Chongqing" > /etc/timezone

USER sonarqube