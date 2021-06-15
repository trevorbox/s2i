#!/bin/bash

microcontainer=$(buildah from registry.access.redhat.com/ubi8/ubi-micro)
micromount=$(buildah mount $microcontainer)

buildah run $microcontainer -- chown 0:0 /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

dnf -y --installroot $micromount install httpd

buildah umount $microcontainer

buildah commit $microcontainer ubi-micro-httpd
