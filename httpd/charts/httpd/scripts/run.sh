#!/bin/bash

set -x

# this is important
rm -f /etc/httpd/conf.d/welcome.conf

/usr/libexec/s2i/assemble

/usr/libexec/s2i/run
