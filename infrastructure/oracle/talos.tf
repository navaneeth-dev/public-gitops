resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "this" {
  cluster_name     = "rizexor"
  machine_type     = "controlplane"
  cluster_endpoint = "https://bom-loadbalancer-2.rizexor.com:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = "rizexor"
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = ["10.0.10.2", "10.0.10.3", "10.0.10.3"]
}

resource "talos_machine_configuration_apply" "this" {
  count = 3

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = "10.0.10.${count.index + 2}"
  
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
      }
    })
  ]
}