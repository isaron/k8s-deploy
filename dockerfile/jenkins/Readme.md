At root directory of project, build jenkins image, run:
```
docker build -f dockerfile/jenkins/Dockerfile -t containers.ssii.com/jenkins/jenkins:lts-alpine .
```
build jnlp-slave image, run:
```
docker build -f dockerfile/jenkins/slave/Dockerfile -t containers.ssii.com/jenkins/jnlp-slave:alpine .
```