# Authentication on OpenShift

## Preparation

```sh
##
## Clone the gitops repo
##
git clone git@github.com:Demo-AI-Edge-Crazy-Train/summit-connect-2025-gitops.git lab-gitops
cd lab-gitops/authentication

##
## Retrieve valid entitlement from a RHEL9 aarch64 machine
##
scp 'root@aarch64-machine:/etc/pki/entitlement/*.pem' files/entitlement
mv files/entitlement/[0-9]*-key.pem files/entitlement/aarch64-key.pem
mv files/entitlement/[0-9]*.pem files/entitlement/aarch64.pem

##
## Retrieve a token for flightctl
##

# Environment
DEMOUSER_PASSWORD="$(oc get secret -n flightctl keycloak-demouser-secret -o=jsonpath='{.data.password}' | base64 -d)"
KEYCLOAK_API="https://$(oc get route -n flightctl keycloak -o jsonpath='{.spec.host}{"\n"}')"
FLIGHTCTL_API=$(oc get route -n flightctl flightctl-api-route -o jsonpath='{.spec.host}{"\n"}')

# Login as a regular user to fill out the client.yaml file with proper values
flightctl login "https://$FLIGHTCTL_API" --insecure-skip-tls-verify --username demouser --password "$DEMOUSER_PASSWORD"

# MANUAL ACTION
# Connect to Keycloak, open realm "flightctl" and assign the "offline_access" realm role to the "demouser" user.

# Retrieve a refresh token with offline access enabled
TOKEN="$(curl -sSfL -X POST "$KEYCLOAK_API/realms/flightctl/protocol/openid-connect/token" -d grant_type=password -d username=demouser -d "password=$DEMOUSER_PASSWORD" -d "scope=offline_access openid" -d client_id=flightctl | jq -r .refresh_token)"

# Inject the refresh token & invalidate the current access token
yq -i ".authentication.auth-provider.config.\"refresh-token\" = \"$TOKEN\" | .authentication.token = \"DUMMY\" | .authentication.auth-provider.config.\"access-token-expiry\" = \"$(date -Isecond)\"" ~/.config/flightctl/client.yaml

# Check that it works
flightctl get fleets

# Copy the config file
cp ~/.config/flightctl/client.yaml files/flightctl/
```

## Deploy the Helm chart

```sh
MASTER_KEY="$(openssl rand -base64 24)"
echo "The master key is ${MASTER_KEY}. Save it somewhere safe!"
helm template auth . --set masterKey=${MASTER_KEY} | oc apply -f -
```

## Configure OpenShift Authentication

```sh
SECRET_NAME="$(oc get secret -n openshift-config -o name --sort-by=.metadata.creationTimestamp --no-headers | grep ^secret/htpasswd | tail -n 1)"
SECRET_NAME="${SECRET_NAME#secret/}"
oc patch oauth/cluster --type='json' -p='[{"op":"add","path":"/spec/identityProviders/-","value":{"htpasswd":{"fileData":{"name":"'$SECRET_NAME'"}},"mappingMethod":"claim","name":"WorkshopUser","type":"HTPasswd"}}]'
```
