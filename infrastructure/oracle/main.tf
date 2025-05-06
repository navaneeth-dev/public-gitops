variable "ssh_public_key" {
}

variable "subnet" {
}

variable "instance_shape" {
  default = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" { default = 1 }

variable "instance_shape_config_memory_in_gbs" { default = 1 }

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

resource "oci_core_virtual_network" "talos_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "talos"
  dns_label      = "talos"
}

resource "oci_core_subnet" "nodes_subnet" {
  cidr_block        = "10.0.10.0/24"
  display_name      = "nodes"
  dns_label         = "nodes"
  security_list_ids = [oci_core_security_list.test_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.test_vcn.id
  route_table_id    = oci_core_route_table.test_route_table.id
  dhcp_options_id   = oci_core_virtual_network.test_vcn.default_dhcp_options_id
}

# resource "oci_core_internet_gateway" "test_internet_gateway" {
#   compartment_id = var.compartment_ocid
#   display_name   = "testIG"
#   vcn_id         = oci_core_virtual_network.test_vcn.id
# }

# resource "oci_core_route_table" "test_route_table" {
#   compartment_id = var.compartment_ocid
#   vcn_id         = oci_core_virtual_network.test_vcn.id
#   display_name   = "testRouteTable"

#   route_rules {
#     destination       = "0.0.0.0/0"
#     destination_type  = "CIDR_BLOCK"
#     network_entity_id = oci_core_internet_gateway.test_internet_gateway.id
#   }
# }

# resource "oci_core_security_list" "test_security_list" {
#   compartment_id = var.compartment_ocid
#   vcn_id         = oci_core_virtual_network.test_vcn.id
#   display_name   = "testSecurityList"

#   egress_security_rules {
#     protocol    = "6"
#     destination = "0.0.0.0/0"
#   }

#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"

#     tcp_options {
#       max = "22"
#       min = "22"
#     }
#   }

#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"

#     tcp_options {
#       max = "3000"
#       min = "3000"
#     }
#   }

#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"

#     tcp_options {
#       max = "3005"
#       min = "3005"
#     }
#   }

#   ingress_security_rules {
#     protocol = "6"
#     source   = "0.0.0.0/0"

#     tcp_options {
#       max = "80"
#       min = "80"
#     }
#   }
# }

variable "talos_image_ocid" {
}

/* Instances */
resource "oci_core_instance" "talos_instances" {
  count = 3

  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "bom-talos-${count.index + 1}"
  shape               = var.instance_shape

  shape_config {
    ocpus = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "bom-talos-${count.index + 1}"
  }

  source_details {
    source_type = "image"
    source_id   = var.talos_image_ocid
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # user_data = base64encode(file("talos.yaml"))
  }
}

# data "oci_core_vnic_attachments" "app_vnics" {
#   compartment_id      = var.compartment_ocid
#   availability_domain = data.oci_identity_availability_domain.ad.name
#   instance_id         = oci_core_instance.free_instance0.id
# }

# data "oci_core_vnic" "app_vnic" {
#   vnic_id = data.oci_core_vnic_attachments.app_vnics.vnic_attachments[0]["vnic_id"]
# }

# output "app" {
#   value = "http://${data.oci_core_vnic.app_vnic.public_ip_address}"
# }
