#!/bin/bash

set -x

# this is important
mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.SAVE
echo "" > /etc/httpd/conf.d/welcome.conf
mkdir -p /tmp/src
cp -r /sources/* /tmp/src/
# Need at least an index.html to prevent httpd from complaining if Indexing disabled
# touch /tmp/src/index/index.html

/usr/libexec/s2i/assemble

/usr/libexec/s2i/run
