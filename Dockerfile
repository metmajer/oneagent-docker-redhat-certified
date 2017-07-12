FROM debian:jessie-slim
MAINTAINER Dynatrace

RUN apt update && apt install -y wget jq

COPY entrypoint.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]