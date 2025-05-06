variable "control_plane_count" {
  default     = 1
  description = "Number of control plane nodes"
}
variable "cluster_name" {
  default = "rizexor"
}

resource "talos_machine_secrets" "this" {}

# Controlplane config
data "talos_machine_configuration" "this" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        certSANs = [oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address]
        time = {
          servers = ["169.254.169.254"]
        }
      }
      cluster = {
        apiServer = {
          certSANs = [oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address]
        }
      }
    })
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    oci_network_load_balancer_network_load_balancer.talos
  ]
  node                 = oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = oci_network_load_balancer_network_load_balancer.talos.ip_addresses[0].ip_address
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
