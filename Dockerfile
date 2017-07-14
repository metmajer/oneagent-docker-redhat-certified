FROM registry.access.redhat.com/rhel7
MAINTAINER Dynatrace

### Atomic/OpenShift Labels - https://github.com/projectatomic/ContainerApplicationGenericLabels
LABEL name="dynatrace/oneagent" \
      vendor="Dynatrace" \
      version="1.x" \
      release="1" \
      summary="Dynatrace is an all-in-one, zero-config monitoring platform designed by and for cloud natives. It is powered by artificial intelligence that identifies performance problems and pinpoints their root causes in seconds." \
      description="Dynatrace OneAgent automatically discovers all technologies, services and applications that run on your host." \
      url="https://www.dynatrace.com/" \
      run='docker run -d --privileged --name ${NAME} --ipc=host --net=host --pid=host -v /:/mnt/root $IMAGE'

### OpenShift labels
LABEL io.k8s.description="Dynatrace OneAgent automatically discovers all technologies, services and applications that run on your host." \
      io.k8s.display-name="Dynatrace OneAgent" \
      io.openshift.tags="Dynatrace,oneagent"

### Atomic Help File - Write in Markdown, it will be converted to man format at build time.
### https://github.com/projectatomic/container-best-practices/blob/master/creating/help.adoc
COPY help.md /tmp

COPY licenses /licenses

RUN set -x \
    && REPOLIST=rhel-7-server-rpms,rhel-7-server-optional-rpms,epel \
    && yum -y update-minimal --disablerepo "*" --enablerepo rhel-7-server-rpms --setopt=tsflags=nodocs \
      --security --sec-severity=Important --sec-severity=Critical \
    && curl -o epel-release-latest-7.noarch.rpm -SL https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm --retry 999 --retry-max-time 0 -C - \
    && rpm -ivh epel-release-latest-7.noarch.rpm && rm epel-release-latest-7.noarch.rpm \
    && yum -y install --disablerepo "*" --enablerepo ${REPOLIST} --setopt=tsflags=nodocs \
      golang-github-cpuguy83-go-md2man jq openssl wget \
    && go-md2man -in help.md -out help.1 \
    && yum -y remove golang-github-cpuguy83-go-md2man \
    && rm -f help.md \
    && yum clean all

COPY dt-root.cert.pem /tmp/dt-root.cert.pem
COPY entrypoint.sh /tmp/entrypoint.sh

RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]