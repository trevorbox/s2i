#!/bin/bash

function update_jwks () {
  curl -k -s -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"  https://kubernetes.default.svc.cluster.local:443/openid/v1/jwks --create-dirs --output /opt/app-root/src/index/openid/v1/jwks
  # It is possible to get the jwks_uri via configuration below, but as state this is unsupported
  # apiVersion: operator.openshift.io/v1
  # kind: KubeAPIServer
  # metadata:
  #  name: cluster
  # spec:
  #   unsupportedConfigOverrides:
  #     apiServerArguments:
  #       service-account-jwks-uri:
  #         - 'https://example.com/whatever'
  # echo $(curl -k -s -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"  https://kubernetes.default.svc.cluster.local:443/.well-known/openid-configuration) > /opt/app-root/src/index/.well-known/openid-configuration
}

rm -f /etc/httpd/conf.d/welcome.conf

mkdir -p /tmp/src/httpd-cfg
cp /configs/*.conf /tmp/src/httpd-cfg/
mkdir -p /tmp/src/index/.well-known
mkdir -p /tmp/src/index/openid/v1
cp /configs/openid-configuration /tmp/src/index/.well-known/openid-configuration


/usr/libexec/s2i/assemble

update_jwks

while true; do sleep ${JWKS_REFRESH_INTERVAL} && echo "$(date) refresh jwks..." && update_jwks; done &

/usr/libexec/s2i/run
