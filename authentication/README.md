# Workshop Users

```sh
helm template auth . --set masterKey=Volcamp2025 | oc apply -f -
```

Get the name of the generated secret:

```sh
oc get secret -n openshift-config |grep ^htpasswd
```

Update oauth/cluster with:

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: htpasswd-
    mappingMethod: claim
    name: WorkshopUser
    type: HTPasswd
```
