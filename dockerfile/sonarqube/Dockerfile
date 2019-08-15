FROM sonarqube:7.9-community

USER root

# COPY ./dockerfile/sonarqube/sonar.properties /opt/sonarqube/conf/

COPY ./certs/ca.cert.pem /usr/local/share/ca-certificates/ca.crt

# RUN chown sonarqube:sonarqube /opt/sonarqube/conf/sonar.properties \
RUN update-ca-certificates \
    && keytool -import -alias ssii.com -file /usr/local/share/ca-certificates/ca.crt -keystore "$JAVA_HOME/lib/security/cacerts" -storepass changeit -trustcacerts -noprompt \
    && echo "Asia/Chongqing" > /etc/timezone

USER sonarqube