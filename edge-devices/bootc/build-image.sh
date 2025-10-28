#!/bin/bash

set -Eeuo pipefail

if [[ "$UID" -ne 0 ]]; then
  echo "This command must be run as root!"
  exit 1
fi

TARGET_IMAGE="localhost/edge-device:latest"

echo "Building image $TARGET_IMAGE..."
podman build --no-cache -t "${TARGET_IMAGE}" .
rm -f edge-device.tar
podman save -o edge-device.tar "${TARGET_IMAGE}"
echo "Image saved to edge-device.tar"
