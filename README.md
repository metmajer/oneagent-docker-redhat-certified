# oneagent-docker-redhat-certified

This is a temporary repository to collaborate on the OneAgent Docker Image for the Red Hat Certified Container Technology partnership.

## Build

```
docker build -t $IMAGE_TAG .
```

## Run

```
docker run -e ONEAGENT_INSTALLER_SCRIPT_URL="$INSTALLER_URL" \
  --privileged=true \
  --pid=host \
  --net=host \
  --ipc=host \
  -v /:/mnt/root \
  "$IMAGE_TAG"
```
