FROM debian:jessie-slim
MAINTAINER Dynatrace

RUN apt update && apt install -y jq openssl wget

COPY dt-root.cert.pem /tmp/dt-root.cert.pem
COPY entrypoint.sh /tmp/entrypoint.sh

RUN chmod +x /tmp/entrypoint.sh

ENTRYPOINT ["/tmp/entrypoint.sh"]