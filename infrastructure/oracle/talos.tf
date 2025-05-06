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
  cluster_endpoint = "https://bom-loadbalancer-2.rizexor.com:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

# 
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for instance in oci_core_instance.controlplane : instance.public_ip]
}

resource "talos_machine_bootstrap" "this" {
  # depends_on = [
  #   talos_machine_configuration_apply.this
  # ]
  node                 = oci_core_instance.controlplane[0].public_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

# resource "talos_machine_configuration_apply" "this" {
#   count = 3

#   client_configuration        = talos_machine_secrets.this.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
#   node                        = "10.0.10.${count.index + 2}"

#   config_patches = [
#     yamlencode({
#       machine = {
#         install = {
#           disk = "/dev/sda"
#         }
#       }
#     })
#   ]
# }

resource "talos_cluster_kubeconfig" "this" {
  # depends_on = [
  #   talos_machine_bootstrap.this
  # ]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = oci_core_instance.controlplane[0].public_ip
}
