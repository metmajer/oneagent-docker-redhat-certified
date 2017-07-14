% DYNATRACE/ONEAGENT (1) Container Image Pages
% Dynatrace LLC

# DESCRIPTION

The `dynatrace/oneagent` image provides the Dynatrace OneAgent component of the [Dynatrace SaaS and Managed](https://www.dynatrace.com/technologies/cloud-and-microservices/docker-monitoring/) platform for all-in-one, real user experience and full-stack application and container monitoring. Please find detailed information in our [online help](https://help.dynatrace.com/infrastructure-monitoring/containers/how-do-i-run-oneagent-with-openshift/).

# USAGE

The `dynatrace/oneagent` image is designed to be run by the atomic `run` command:

```
atomic run dynatrace/oneagent
```

This starts the container with selected privileges to the host and with the root directory bind mounted inside the container to install Dynatrace OneAgent on the host.

# LABELS

The `dynatrace/onagent` container includes the following LABEL settings:

That atomic command runs the docker command set in this label:

`RUN`=docker run -d --privileged --name NAME --ipc=host --net=host --pid=host -v /:/mnt/root IMAGE

The contents of the RUN label tells an `atomic run dynatrace/oneagent` command to open various privileges to the host (described later), mount the root directory into the container, set the name of the container and run the Dynatrace OneAgent installation.

`Name=`dynatrace/oneagent

`Release=`1.x

`Version=`1.x

`Build-date=`2017-07-14

# SECURITY IMPLICATIONS

The `dynatrace/oneagent` container is what is referred to as a super-privileged container. It is designed to have almost complete access to the host system as root user. The following docker command options open selected privileges to the host:

`-d`

Runs continuously as a daemon process in the background.

`--privileged`

Turns off security separation, so a process running as root in the container would have the same access to the host as it would if it were run directly on the host.

`--ipc=host`

Allows processes run inside the container to directly access the host’s IPC namespace.

`--net=host`

Allows processes run inside the container to directly access host network interfaces.

`--pid=host`

Allows processes run inside the container to see and work with all processes in the host process table.

` -v /:/mnt/root`

Mounts the host's root directory into the container at `/mnt/root` to enable the installation of Dynatrace OneAgent in `/opt/dynatrace` on the host.

# AUTHORS

The Dynatrace Team