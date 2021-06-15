#!/bin/bash

# Tested on fedora 30

NODEJS_VERSION=14

microcontainer=$(buildah from registry.access.redhat.com/ubi8/ubi-micro)
micromount=$(buildah mount $microcontainer)

echo -e "[nodejs]\nname=nodejs\nstream=$NODEJS_VERSION\nprofiles=\nstate=enabled\n" > ./nodejs.module

buildah copy $microcontainer './nodejs.module' '/etc/dnf/modules.d/nodejs.module'

dnf -y --nodocs install \
  --installroot $micromount \
  nodejs nodejs-nodemon npm
  

dnf clean all \
  --installroot $micromount

buildah umount $microcontainer

buildah commit $microcontainer ubi8-micro-nodejs-14
