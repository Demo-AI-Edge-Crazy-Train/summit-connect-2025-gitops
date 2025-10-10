# Edge Devices lab on AWS EC2

## Development on local machine

Pre-requisites: Libvirt on Fedora

```sh
cd cloud-init
./dev.sh
```

## Installation on AWS EC2

Pre-requisites:

- Terraform
- OpenSSL
- Bash
- mkpasswd
- gzip

```sh
cp cloud-init/user-data.yaml.template cloud-init/user-data.yaml # Edit the file to fill out the placeholders
terraform init
cat > terraform.tfvars <<EOF
route53_zone = "sandbox1893.opentlc.com"
machine_count = 40
EOF
terraform apply
```
