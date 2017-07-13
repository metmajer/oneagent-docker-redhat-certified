# oneagent-docker-redhat-certified

This is a temporary repository to collaborate on the OneAgent Docker Image for the Red Hat Certified Container Technology partnership.

The Debian instructions below are good enough for a quick test build. The RHEL build below that is subject to certification needs to be built on a RHEL machine with a valid Red Hat subscription.

## Debian

### Build

```
docker build -t $IMAGE_TAG .
```

### Run

```
docker run -e ONEAGENT_INSTALLER_SCRIPT_URL="$INSTALLER_URL" \
  --privileged=true \
  --pid=host \
  --net=host \
  --ipc=host \
  -v /:/mnt/root \
  "$IMAGE_TAG"
```

...or use the `dynatrace-oneagent.yml` OpenShift template file.

If you are runnig OneAgent installer from Managed cluster and you don't have valid SSL certificate deployed on your cluster then you can disable certificate checking otherwise installation will fail.

```
docker run -e ONEAGENT_INSTALLER_SCRIPT_URL="$INSTALLER_URL" \
  -e ONEAGENT_INSTALLER_SKIP_CERTIFICATE_CHECK=true \
  --privileged=true \
  --pid=host \
  --net=host \
  --ipc=host \
  -v /:/mnt/root \
  "$IMAGE_TAG"
```

## RHEL

### Prerequisites

Start with spinning up a RHEL 7.3 VM instance using [https://opennebula.lab.dynatrace.org](OpenNebula). Then, as root user, do:

```
subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms
yum install docker
systemctl enable docker
systemctl start docker
docker info
```

### Build

```
git clone https://github.com/Dynatrace/oneagent-docker-redhat-certified.git
cd oneagent-docker-redhat-certified
docker build --pull -t "$IMAGE_TAG" -f Dockerfile.rhel .
```

### Push

tbd.
