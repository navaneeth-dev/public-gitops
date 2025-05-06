variable "ssh_public_key" {
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

// Create VCN, subnets and sec lists
resource "oci_core_virtual_network" "talos_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "talos"
  dns_label      = "talos"
}

resource "oci_core_subnet" "nodes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.10.0/24"

  display_name = "nodes"
  dns_label    = "nodes"

  prohibit_internet_ingress = true
  route_table_id            = oci_core_route_table.route_table.id
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_subnet" "loadbalancers" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.60.0/24"

  display_name = "loadbalancers"
  dns_label    = "loadbalancers"

  prohibit_internet_ingress = false
  route_table_id            = oci_core_route_table.route_table.id
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "talos_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "Internet Gateway"
  vcn_id         = oci_core_virtual_network.talos_vcn.id
}

resource "oci_core_route_table" "route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  display_name   = "Route Table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.talos_internet_gateway.id
  }
}

resource "oci_core_default_security_list" "default_sec_list" {
  manage_default_resource_id = oci_core_virtual_network.talos_vcn.default_security_list_id

  # Allow All Egress Traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # Allow Kubenetes API server IPv4
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "6443"
      min = "6443"
    }
  }

  # Allow Talos Ingress
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "50000"
      min = "50000"
    }
  }
}

resource "oci_network_load_balancer_network_load_balancer" "talos" {
  compartment_id = var.compartment_ocid
  display_name   = "talos"
  subnet_id      = oci_core_subnet.loadbalancers.id
  is_private     = false # Make the load balancer private
}

// K8S load balance
resource "oci_network_load_balancer_backend_set" "k8s_api" {
  name                     = "${var.cluster_name}-k8s-api-backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    port               = 6443
    interval_in_millis = 10000
    protocol           = "HTTPS"
    return_code        = 401
    url_path           = "/readyz"
  }
}

resource "oci_network_load_balancer_backend" "k8s_api" {
  count                    = var.control_plane_count
  backend_set_name         = oci_network_load_balancer_backend_set.k8s_api.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos.id
  port                     = 6443
  ip_address               = oci_core_instance.controlplane[count.index].private_ip
}

resource "oci_network_load_balancer_listener" "k8s_api" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos.id
  name                     = "${var.cluster_name}-k8s-api-listener"
  default_backend_set_name = oci_network_load_balancer_backend_set.k8s_api.name
  port                     = 6443
  protocol                 = "TCP"
}

// Talos load balance
resource "oci_network_load_balancer_backend_set" "talos" {
  name                     = "${var.cluster_name}-talos-backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol           = "TCP"
    port               = 50000
    interval_in_millis = 10000
  }
}

resource "oci_network_load_balancer_backend" "talos" {
  count                    = var.control_plane_count
  backend_set_name         = oci_network_load_balancer_backend_set.talos.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos.id
  port                     = 50000
  ip_address               = oci_core_instance.controlplane[count.index].private_ip
}

resource "oci_network_load_balancer_listener" "talos" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos.id
  name                     = "${var.cluster_name}-talos-listener"
  default_backend_set_name = oci_network_load_balancer_backend_set.talos.name
  port                     = 50000
  protocol                 = "TCP"
}

variable "talos_image_ocid" {
}

/* Instances */
resource "oci_core_instance" "controlplane" {
  count = var.control_plane_count

  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "bom-talos-${count.index + 1}"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.nodes.id
    display_name     = "primaryvnic"
    assign_public_ip = false
    hostname_label   = "bom-talos-${count.index + 1}"
  }

  source_details {
    source_type = "image"
    source_id   = var.talos_image_ocid
  }

  metadata = {
    user_data = base64encode(data.talos_machine_configuration.this.machine_configuration)
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
