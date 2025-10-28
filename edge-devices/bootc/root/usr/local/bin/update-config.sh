#!/bin/bash

set -Eeuo pipefail

if grep -q "ec2.id:" /etc/flightctl/config.yaml; then
  echo "Configuration already updated. Exiting."
  exit 0
fi

if [[ "$UID" -ne 0 ]]; then
  echo "This command must be run as root!"
  exit 1
fi

TOKEN="$(curl -sSfL -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"
INSTANCE_ID="$(curl -sSfL -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)"
INSTANCE_NAME="$(curl -sSL -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Name)"
INSTANCE_FLEET="$(curl -sSL -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/Fleet)"

echo "Updating flightctl configuration with instance ID: $INSTANCE_ID, Name: $INSTANCE_NAME, Fleet: $INSTANCE_FLEET"
if [ -n "$INSTANCE_ID" ]; then
    yq -i e ".default-labels += {\"ec2.id\": \"$INSTANCE_ID\"}" /etc/flightctl/config.yaml
fi
if [ -n "$INSTANCE_NAME" ]; then
    yq -i e ".default-labels += {\"ec2.name\": \"$INSTANCE_NAME\"}" /etc/flightctl/config.yaml
fi
if [ -n "$INSTANCE_FLEET" ]; then
    yq -i e ".default-labels += {\"fleet\": \"$INSTANCE_FLEET\"}" /etc/flightctl/config.yaml
fi

echo "Updated flightctl configuration."
