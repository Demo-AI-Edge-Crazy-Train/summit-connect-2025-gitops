# Red Hat Summit Connect 2025 - GitOps manifests

## Cleanup

```sh
for ns in $(oc get ns -o name |grep namespace/user); do
  oc delete --wait=false $ns
done
watch sh -c 'oc get ns -o name |grep namespace/user | wc -l'
```
