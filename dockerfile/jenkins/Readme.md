At root directory of project, build jenkins image, run:
```
docker build -f dockerfile/jenkins/Dockerfile -t containers.ssii.com/jenkins/jenkins:lts .
```
build jnlp-slave image, run:
```
docker build -f dockerfile/jenkins/Dockerfile_slave -t containers.ssii.com/jenkins/jnlp-slave:3.27-1 .
```