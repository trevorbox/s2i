#!/bin/bash

set -ex

function update_jwks () {
  curl -k -s -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"  https://kubernetes.default.svc.cluster.local:443/openid/v1/jwks --create-dirs --output /opt/app-root/src/index/openid/v1/jwks
  echo $(curl -k -s -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"  https://kubernetes.default.svc.cluster.local:443/.well-known/openid-configuration) | sed 's/192.168.126.11:6443//' > /opt/app-root/src/index/.well-known/openid-configuration
}

rm -f /etc/httpd/conf.d/welcome.conf

mkdir -p /tmp/src/httpd-cfg
cp /configs/* /tmp/src/httpd-cfg/
mkdir -p /tmp/src/index/.well-known
mkdir -p /tmp/src/index/openid/v1



/usr/libexec/s2i/assemble

update_jwks

while true; do sleep 10s && echo "$(date) retrieve jwks..." && update_jwks; done &

/usr/libexec/s2i/run
