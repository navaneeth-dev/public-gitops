<h1 align="center">public-gitops</h1>
<p align="center">Production grade HA Kubernetes cluster for public servics using GitOps.</p>

![ArgoCD](https://github.com/navaneeth-dev/public-gitops/blob/main/assets/argocd.png)

## Folder Structure

```
apps: Used for Argo applications which need two environments (prod and staging)
appsets: Used to add new environments like staging, qa
cluster-wide: Used for applications that required ONLY a single instance running
```
