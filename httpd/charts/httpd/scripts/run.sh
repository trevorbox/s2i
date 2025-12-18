#!/bin/bash

set -x

rm -f /etc/httpd/conf.d/welcome.conf

# mkdir -p /opt/app-root/src/files
# mkdir -p /tmp/src/httpd-cfg
# cp /configs/*.conf /tmp/src/httpd-cfg/
# mkdir -p /tmp/src/index
# touch /tmp/src/index/index.html
# mkdir -p /tmp/src/index/openid/v1

# rm -rf ./.pki

/usr/libexec/s2i/assemble

# rm /opt/app-root/src/index.html

/usr/libexec/s2i/run
