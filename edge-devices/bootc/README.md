# Bootc AWS EC2 AMI image for Edge Devices

## Prerequisites

- RHEL 9 aarch64 machine with Podman installed and properly registered with subscription-manager
- AWS CLI configured with your credentials

## Prepare the AWS environment

Create an S3 bucket to store temporary files during the AMI creation process:

```sh
BUCKET_NAME="crazy-train-lab-edge-device-ami"
AWS_REGION="eu-west-3"
aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION
aws iam create-role --role-name vmimport --assume-role-policy-document file:///dev/stdin <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file:///dev/stdin <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource": [
            "arn:aws:s3:::$BUCKET_NAME",
            "arn:aws:s3:::$BUCKET_NAME/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      }
   ]
}
EOF
```

## Fill out the configuration

You will need to expose the OpenShift image registry to the edge devices. You can do this by creating a route in the OpenShift console and using the route hostname in the `config.toml` file.

```sh
oc patch config.imageregistry cluster -n openshift-image-registry --type merge -p '{"spec":{"defaultRoute":true}}'
```

Then get the route hostname.

```sh
OPENSHIFT_REGISTRY=$(oc get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}{"\n"}')
echo "OpenShift image registry is at $OPENSHIFT_REGISTRY"
```

Create a pull secret for the OpenShift registry.

```sh
oc create namespace edge-devices
oc create serviceaccount edge-devices -n edge-devices
OPENSHIFT_REGISTRY_TOKEN="$(oc create token edge-devices -n edge-devices --duration=$((365*24))h)"
echo "OpenShift registry auth token is $OPENSHIFT_REGISTRY_TOKEN"
OPENSHIFT_REGISTRY_AUTH="$(echo -n "edge-devices:$OPENSHIFT_REGISTRY_TOKEN" | base64 -w0)"
```

Give the rights to pull images from the OpenShift registry over the 40 user namespaces.

```sh
for i in $(seq 1 40); do
  oc adm policy add-role-to-user system:image-puller system:serviceaccount:edge-devices:edge-devices -n user$i-test
done
```

Install the flightctl CLI.

```sh
sudo dnf -y copr enable @redhat-et/flightctl fedora-42-x86_64
sudo dnf install -y flightctl
```

Login on the flightctl API.

```sh
FLIGHTCTL_API=$(oc get route -n flightctl flightctl-api-route -o jsonpath='{.spec.host}{"\n"}')
echo "Flightctl API is at $FLIGHTCTL_API"
echo "Flightctl demo user password is:"
oc get secret -n flightctl keycloak-demouser-secret -o=jsonpath='{.data.password}' | base64 -d
flightctl login https://${FLIGHTCTL_API} --web --insecure-skip-tls-verify
flightctl certificate request --signer=enrollment --expiration=365d --output=embedded > config.yaml
FLIGHTCTL_CONFIG_YAML="$(cat config.yaml)"
```

Retrieve your SSH public key.

```sh
SSH_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
```

Generate the final configuration file.

```sh
export FLIGHTCTL_CONFIG_YAML SSH_AUTHORIZED_KEYS OPENSHIFT_REGISTRY OPENSHIFT_REGISTRY_AUTH
envsubst < config.toml.template > config.toml
```

## Build the AMI

```sh
sudo ./build-image.sh
sudo ./build-ami.sh "crazy-train-lab-edge-device-ami" "crazy-train-lab-edge-device-ami" "eu-west-3"
```
