#!/bin/bash

set -Eeuo pipefail

if [[ "$UID" -ne 0 ]]; then
  echo "This command must be run as root!"
  exit 1
fi

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <ami-image-name> <aws-bucket-name> <aws-region>"
  exit 1
fi

if [ ! -f "config.toml" ]; then
  echo "Error: config.toml not found!"
  exit 1
fi

TARGET_IMAGE="localhost/edge-device:latest"
AMI_IMAGE_NAME="$1"
AWS_BUCKET_NAME="$2"
AWS_REGION="$3"

temp_dir="$(mktemp -d)"
mkdir -p $temp_dir/{output,aws}
trap 'rm -rf "$temp_dir"' EXIT

declare -a PODMAN_ARGS=( --rm -it --privileged --pull=newer --security-opt label=type:unconfined_t -v /var/lib/containers/storage:/var/lib/containers/storage -v $temp_dir/output:/output )
declare -a BOOTC_IMAGE_BUILDER_ARGS=( --type ami "$TARGET_IMAGE" --aws-ami-name "$AMI_IMAGE_NAME" --aws-bucket-name "$AWS_BUCKET_NAME" --aws-region "$AWS_REGION" )
if [ -n "$AWS_CONFIG_FILE" ] && [ -f "$AWS_CONFIG_FILE" ] && [ -n "$AWS_SHARED_CREDENTIALS_FILE" ] && [ -f "$AWS_SHARED_CREDENTIALS_FILE" ]; then
  echo "Using AWS config file $AWS_CONFIG_FILE"
  echo "Using AWS shared credentials file $AWS_SHARED_CREDENTIALS_FILE"
  cp "$AWS_CONFIG_FILE" "$temp_dir/aws/config"
  cp "$AWS_SHARED_CREDENTIALS_FILE" "$temp_dir/aws/credentials"
  PODMAN_ARGS+=( "-v" "$temp_dir/aws:/root/.aws:ro" )
fi

PODMAN_ARGS+=( "-v" "$temp_dir/output:/output" )

if [ -f "config.toml" ]; then
  BOOTC_IMAGE_BUILDER_ARGS+=( "--config" "/config.toml" )
  PODMAN_ARGS+=( "-v" "$PWD/config.toml:/config.toml:ro" )
fi

echo "Building and pushing image $AMI_IMAGE_NAME using bootc-image-builder with arguments: ${BOOTC_IMAGE_BUILDER_ARGS[*]}"
podman run "${PODMAN_ARGS[@]}" registry.redhat.io/rhel10/bootc-image-builder:latest "${BOOTC_IMAGE_BUILDER_ARGS[@]}" "$TARGET_IMAGE"
