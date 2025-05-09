import * as k8s from "@pulumi/kubernetes";

const argoCDNamespace = new k8s.core.v1.Namespace("argocd-ns", {
  metadata: {
    name: "argocd",
  },
});

const argoCD = new k8s.yaml.v2.ConfigFile(
  "argocd",
  {
    file: "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml",
  },
  { dependsOn: [argoCDNamespace] }
);

const argoCDRootApp = new k8s.yaml.v2.ConfigFile(
  "argocd-root-app",
  {
    file: "../../root-argocd-app.yaml",
  },
  { dependsOn: [argoCD] }
);
