# Dynatrace OneAgent in Docker for the Red Hat Container Catalog

This repository contains build files and basic documentation on building and shipping a Dynatrace OneAgent Docker image for the [Red Hat Container Catalog (RHCC)](). For detailed instructions on how to run this image on [OpenShift Container Platform](https://www.openshift.com/container-platform/), please have a look at [help.dynatrace.com](https://help.dynatrace.com/infrastructure-monitoring/containers/how-do-i-monitor-openshift-container-platform/).

## Prerequisites

The Docker image is based on the official `registry.access.redhat.com/rhel7` Docker image and has to be built on a RHEL 7 host. To install `docker` on this host, do:

```
sudo subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms
sudo yum install docker
sudo systemctl enable docker
sudo systemctl start docker
```

## Build

```
git clone https://github.com/Dynatrace/oneagent-docker-redhat-certified.git
cd oneagent-docker-redhat-certified
docker build -t dynatrace/oneagent .
```

## Ship

Then, follow the instructions under the *Upload Your Image* section in the *Dynatrace OneAgent* project of the [Red Hat Container Zone](https://connect.redhat.com/zones/containers) (login required).