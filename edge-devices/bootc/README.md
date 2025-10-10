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

## Register a custom RHEL 9.4 Beta AMI on AWS for aarch64

$ aws ec2 import-snapshot --description "Red Hat Enterprise Linux 9.4 Beta for aarch64" --disk-container "file:///dev/stdin" <<EOF
{
    "Description": "Red Hat Enterprise Linux 9.4 Beta for aarch64",
    "Format": "raw",
    "UserBucket": {
        "S3Bucket": "$BUCKET_NAME",
        "S3Key": "rhel-9.4-beta-aarch64-kvm.raw"
    }
}
EOF

{
    "Description": "Red Hat Enterprise Linux 9.4 Beta for aarch64",
    "ImportTaskId": "import-snap-04de8143bd0fafc7c",
    "SnapshotTaskDetail": {
        "Description": "Red Hat Enterprise Linux 9.4 Beta for aarch64",
        "DiskImageSize": 0.0,
        "Progress": "0",
        "Status": "active",
        "StatusMessage": "pending",
        "UserBucket": {
            "S3Bucket": "demo-crazy-train-ami-repo",
            "S3Key": "rhel-9.4-beta-aarch64-kvm.raw"
        }
    },
    "Tags": []
}

$ watch aws ec2 describe-import-snapshot-tasks --import-task-ids import-snap-04de8143bd0fafc7c

{
    "ImportSnapshotTasks": [
        {
            "Description": "Red Hat Enterprise Linux 9.4 Beta for aarch64",
            "ImportTaskId": "import-snap-04de8143bd0fafc7c",
            "SnapshotTaskDetail": {
                "Description": "Red Hat Enterprise Linux 9.4 Beta for aarch64",
                "DiskImageSize": 10737418240.0,
                "Format": "RAW",
                "SnapshotId": "snap-04be0bd28c48610f8",
                "Status": "completed",
                "UserBucket": {
                    "S3Bucket": "demo-crazy-train-ami-repo",
                    "S3Key": "rhel-9.4-beta-aarch64-kvm.raw"
                }
            },
            "Tags": []
        }
    ]
}

$ aws ec2 register-image --name RHEL94-beta-aarch64 --architecture arm64 --virtualization-type hvm --ena-support --root-device-name /dev/xvda --block-device-mappings DeviceName=/dev/xvda,Ebs={SnapshotId=snap-04be0bd28c48610f8}

{
    "ImageId": "ami-011021d313a14c620"
}
```

Ensuite, je mets à jour mon script terraform pour prendre en compte la nouvelle AMI.

```terraform
data "aws_ami" "rhel" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL94-beta-aarch64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  owners = ["881547341921"]
}
```
