import * as k8s from "@pulumi/kubernetes";

const argoCD = new k8s.kustomize.v2.Directory("argoCDKustomize", {
  directory: "./bootstrap",
});

const argoCDRootApp = new k8s.yaml.v2.ConfigFile(
  "argocd-root-app",
  {
    file: "../../root-argocd-app.yaml",
  },
  { dependsOn: [argoCD] }
);
