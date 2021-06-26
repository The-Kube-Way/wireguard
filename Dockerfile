FROM alpine:latest

LABEL Maintainer "The-Kube-Way (https://github.com/The-Kube-Way/wireguard)"

RUN apk add --no-cache --update wireguard-tools iptables

COPY bin/ /usr/local/bin

ENTRYPOINT [ "sh", "/usr/local/bin/run.sh" ]
