locals {
  nixos_bastion_users = [for i in oci_bastion_session.nixos_session : "${i.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"]
}

resource "null_resource" "ssh" {
  count = var.loadbalancer_count

  depends_on = [oci_bastion_session.nixos_session]
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "ssh -S bastion_session_nixos${count.index} -O exit ${local.nixos_bastion_users[count.index]}; ssh -M -S bastion_session_nixos${count.index} -fNL 5000${count.index + 1}:10.0.70.${count.index + 2}:22 ${local.nixos_bastion_users[count.index]}"
  }
}

resource "local_file" "ansible_inventory" {
  content  = "[vps]\nlocalhost ansible_port=50001"
  filename = "${path.module}./ansible/hosts.ini"
}
