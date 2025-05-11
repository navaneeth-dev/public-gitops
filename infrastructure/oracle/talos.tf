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
  endpoint = "127.0.0.1"
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
        sysctls = {
          "vm.nr_hugepages" = 1024
        }
        kernel = {
          modules = [{ name = "nvme-tcp" }, { name = "vfio_pci" }]
        }
        kubelet = {
          extraArgs = {
            "rotate-server-certificates" = true
          }
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = true
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

locals {
  talos_bastion_user   = "${oci_bastion_session.talos_session.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
  k8s_api_bastion_user = "${oci_bastion_session.k8s_api_session.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
}

resource "null_resource" "talos" {
  depends_on = [oci_bastion_session.talos_session]
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "ssh -S bastion_session_talos -O exit ${local.talos_bastion_user}; ssh -M -S bastion_session_talos -fNL 50000:10.0.60.200:50000 ${local.talos_bastion_user}"
  }
}

resource "null_resource" "k8s_api" {
  depends_on = [oci_bastion_session.k8s_api_session]
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "ssh -S bastion_session_k8s_api -O exit ${local.k8s_api_bastion_user}; ssh -M -S bastion_session_k8s_api -fNL 6443:10.0.60.200:6443 ${local.k8s_api_bastion_user}"
  }
}

# Bootstrap 1 controlplane
resource "talos_machine_bootstrap" "this" {
  depends_on = [
    oci_network_load_balancer_backend.talos,
    oci_network_load_balancer_backend.k8s_api,
    oci_bastion_session.k8s_api_session,
    oci_bastion_session.talos_session,
    null_resource.talos
  ]

  endpoint             = local.endpoint
  node                 = oci_core_instance.controlplane[0].private_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_cluster_health" "this" {
  depends_on = [talos_machine_bootstrap.this, null_resource.talos]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [local.endpoint]
  control_plane_nodes  = [for instance in oci_core_instance.controlplane : instance.private_ip]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration

  endpoints = [local.endpoint]
  nodes     = [for instance in oci_core_instance.controlplane : instance.private_ip]
}

# Retrieve kubeconfig from talosctl
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    null_resource.k8s_api
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

output "bastion_session_talos" {
  value       = "${oci_bastion_session.talos_session.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
  description = "Bastion Talos SSH host"
}

output "bastion_session_k8s_api" {
  value       = "${oci_bastion_session.k8s_api_session.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
  description = "Bastion K8S API SSH host"
}
