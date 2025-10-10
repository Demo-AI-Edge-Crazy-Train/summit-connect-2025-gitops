# Edge Devices lab on AWS EC2

## Prepare the Edge Device image


```sh
cd bootc
sudo ./build-image.sh
cp config.toml.template config.toml # Edit config.toml to add your SSH public key, registry credentials, etc.
sudo ./build-ami.sh
```

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
terraform init
terraform apply
```
