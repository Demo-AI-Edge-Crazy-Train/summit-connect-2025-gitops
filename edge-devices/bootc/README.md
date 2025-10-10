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

## Build the AMI

```sh
sudo ./build-image.sh
cp config.toml.template config.toml # Edit config.toml to add your SSH public key, registry credentials, etc.
sudo ./build-ami.sh "crazy-train-lab-edge-device-ami" "crazy-train-lab-edge-device-ami" "eu-west-3"
```
