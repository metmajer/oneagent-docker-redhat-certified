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

## Todo

- Validate that the server's certificate holder is Dynatrace
- Build the image on Red Hat's official 'rhel' base image (MaEt)
