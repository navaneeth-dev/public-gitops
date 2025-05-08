variable "control_plane_count" {
  default     = 3
  description = "Number of control plane nodes"
}
variable "cluster_name" {
  default = "rizexor"
}

resource "talos_machine_secrets" "this" {}

locals {
  # L4 Load balancer endpoint for talos and k8s api
  endpoint = oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address
}

# Controlplane config
data "talos_machine_configuration" "this" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        certSANs = [local.endpoint]
        time = {
          servers = ["169.254.169.254"]
        }
        kubelet = {
          extraArgs = {
            "rotate-server-certificates" = true
          }
        }
      }
      cluster = {
        extraManifests = [
          "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
          "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
        ]
        apiServer = {
          certSANs = [local.endpoint]
        }
      }
    })
  ]
}

# Bootstrap 1 controlplane
resource "talos_machine_bootstrap" "this" {
  depends_on = [
    oci_network_load_balancer_backend.talos,
    oci_network_load_balancer_backend.k8s_api
  ]

  endpoint             = local.endpoint
  node                 = oci_core_instance.controlplane[0].private_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration

  endpoints = [local.endpoint]
  nodes     = [for instance in oci_core_instance.controlplane : instance.private_ip]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]

  client_configuration = talos_machine_secrets.this.client_configuration

  endpoint = local.endpoint
  node     = oci_core_instance.controlplane[0].private_ip
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
