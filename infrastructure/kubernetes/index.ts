import * as k8s from "@pulumi/kubernetes";
import * as path from "path";

const argoCD = new k8s.kustomize.v2.Directory("argocd", {
  directory: "../../cluster-wide-k8s/argocd",
});
const argoCDRootApp = new k8s.yaml.ConfigFile("argocd-root-app", {
    file: "../../root-argocd-app.yaml",
}, { dependsOn: [argoCD] });
