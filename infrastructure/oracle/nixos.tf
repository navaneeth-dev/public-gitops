locals {
  ipv4 = [for inst in oci_core_instance.loadbalancers : inst.private_ip]
}
resource "null_resource" "ssh" {
  count = var.loadbalancer_count

  depends_on = [oci_bastion_session.nixos_session]
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "sleep 2; ssh -M -S bastion_session_nixos${count.index} -fNL 5000${count.index + 1}:10.0.70.${count.index + 2}:22 ${oci_bastion_session.nixos_session[count.index].bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
  }
}

module "deploy" {
  depends_on = [talos_cluster_kubeconfig.this]

  count = var.loadbalancer_count

  source = "github.com/nix-community/nixos-anywhere/terraform/all-in-one"
  # with flakes
  nixos_system_attr      = "../nix#nixosConfigurations.generic.config.system.build.toplevel"
  nixos_partitioner_attr = "../nix#nixosConfigurations.generic.config.system.build.diskoScript"

  target_host = "localhost"
  target_port = "5000${count.index + 1}"
  target_user = "root"

  # when instance id changes, it will trigger a reinstall
  instance_id = oci_bastion_session.nixos_session[count.index].id
  # useful if something goes wrong
  # debug_logging          = true
  # build the closure on the remote machine instead of locally
  # build_on_remote        = true
  # script is below
  extra_files_script = "${path.module}./nix/copy_keys_txt.sh"
  # Optional, arguments passed to special_args here will be available from a NixOS module in this example the `terraform` argument:
  # { terraform, ... }: {
  #    networking.interfaces.enp0s3.ipv4.addresses = [{ address = terraform.ip;  prefixLength = 24; }];
  # }
  # Note that this will means that your NixOS configuration will always depend on terraform!
  # Skip to `Pass data persistently to the NixOS` for an alternative approach
  #special_args = {
  #  terraform = {
  #    ip = "192.0.2.0"
  #  }
  #}
}
