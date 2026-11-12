#!/bin/sh
#
# build-deb.sh — build the .deb in a clean Debian trixie container, so the
# result does not depend on what the build machine has installed. The
# package is architecture-independent, so any host can build it.
#
#   ./build-deb.sh            leaves pyra-sound_<version>_all.deb in dist/
#
# Needs docker. On a Debian machine, dpkg-buildpackage -b -uc -us works too.
#
set -eu
cd "$(dirname "$0")"
mkdir -p dist
docker run --rm -e DEBIAN_FRONTEND=noninteractive \
	-v "$PWD:/src:ro" -v "$PWD/dist:/out" debian:trixie sh -euc '
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends build-essential debhelper lintian >/dev/null
	# Build from a copy: dpkg-buildpackage writes next to the tree and
	# into it, and the checkout is mounted read-only.
	mkdir /build
	cp -r /src /build/pyra-sound
	cd /build/pyra-sound
	rm -rf dist
	dpkg-buildpackage -b -uc -us
	lintian --info ../*.changes || true
	cp ../*.deb /out/
	chown '"$(id -u):$(id -g)"' /out/*.deb
'
ls -l dist/
