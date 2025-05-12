variable "ssh_public_key" {
}

variable "instance_shape" {
  default = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" { default = 2 }

variable "instance_shape_config_memory_in_gbs" { default = 8 }

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
  is_ipv6enabled = true
}

resource "oci_core_internet_gateway" "talos_internet_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id

  display_name = "Internet Gateway"
}

resource "oci_core_nat_gateway" "talos_nodes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id

  display_name = "NAT Gateway"
}

resource "oci_core_subnet" "nodes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.10.0/24"

  display_name = "nodes"
  dns_label    = "nodes"

  prohibit_internet_ingress = true
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_subnet" "loadbalancers" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.60.0/24"

  display_name = "loadbalancers"
  dns_label    = "loadbalancers"

  prohibit_internet_ingress = true
  route_table_id            = oci_core_route_table.internet_routing.id
  security_list_ids         = [oci_core_security_list.loadbalancers_sec_list.id]
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_subnet" "public_lbs" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.70.0/24"
  ipv6cidr_block = cidrsubnet(oci_core_virtual_network.talos_vcn.ipv6cidr_blocks[0], 8, 0)

  display_name = "publiclbs"
  dns_label    = "publiclbs"

  prohibit_internet_ingress = false
  route_table_id            = oci_core_route_table.internet_routing.id
  security_list_ids         = [oci_core_security_list.public_lbs_sec_list.id]
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_subnet" "bastion" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.30.0/24"

  display_name = "bastion"
  dns_label    = "bastion"

  prohibit_internet_ingress = true
  route_table_id            = oci_core_route_table.internet_routing.id
  security_list_ids         = [oci_core_security_list.bastion_sec_list.id]
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_default_route_table" "nat_routing" {
  manage_default_resource_id = oci_core_virtual_network.talos_vcn.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.talos_nodes.id
  }
}

resource "oci_core_route_table" "internet_routing" {
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  compartment_id = var.compartment_ocid

  display_name = "Public Internet Routing"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.talos_internet_gateway.id
  }

  route_rules {
    destination       = "::/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.talos_internet_gateway.id
  }
}

resource "oci_core_security_list" "loadbalancers_sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  display_name   = "Private Load Balancer security list"

  # IPv4: Allow all egress traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # IPv4: Allow Talos from Bastion
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.30.0/24"

    tcp_options {
      max = "50000"
      min = "50000"
    }
  }

  # IPv4: Allow K8S from Bastion
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.30.0/24"

    tcp_options {
      max = "6443"
      min = "6443"
    }
  }
}

resource "oci_core_security_list" "public_lbs_sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  display_name   = "Public Load Balancer security list"

  # IPv4: Allow all egress traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # IPv6: Allow all egress traffic
  egress_security_rules {
    protocol    = "all"
    destination = "::/0"
  }

  # IPv4: Allow SSH from Bastion
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.30.0/24"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  # IPv4: Allow HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "443"
      min = "443"
    }
  }

  # IPv4: Allow HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }

  # IPv6: Allow HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "::/0"

    tcp_options {
      max = "443"
      min = "443"
    }
  }

  # IPv6: Allow HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "::/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }
}

resource "oci_core_security_list" "bastion_sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  display_name   = "Bastion security list"

  # IPv4: Allow all egress traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # IPv4: Allow Talos traffic
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "50000"
      min = "50000"
    }
  }

  # IPv4: Allow K8S traffic
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "6443"
      min = "6443"
    }
  }

  # IPv4: Allow SSH traffic
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }
}

resource "oci_core_default_security_list" "default_sec_list" {
  manage_default_resource_id = oci_core_virtual_network.talos_vcn.default_security_list_id

  # IPv4: Allow all egress traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # IPv4: Allow all internal communication in the subnet for Kubernetes
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.10.0/24"
  }

  # IPv4: Allow Healthchecks for Talos from Private LBs
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.60.0/24"

    tcp_options {
      max = "50000"
      min = "50000"
    }
  }

  # IPv4: Allow Healthchecks for K8S Api from Private LBs
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.60.0/24"

    tcp_options {
      max = "6443"
      min = "6443"
    }
  }

  # IPv4: Allow public loadbalancer to talk to NodePort HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.70.0/24"

    tcp_options {
      max = "32579"
      min = "32579"
    }
  }

  # IPv4: Allow public loadbalancer to talk to NodePort HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.70.0/24"

    tcp_options {
      max = "31258"
      min = "31258"
    }
  }

  # IPv4: Allow Bastion to talk to Kubenetes API server via NLB
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.30.0/24"

    tcp_options {
      max = "6443"
      min = "6443"
    }
  }

  # IPv4: Allow Bastion to talk to Talos API server via NLB
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.30.0/24"

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
  is_private     = true # Make the load balancer private

  assigned_private_ipv4 = "10.0.60.200"
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
  count = var.control_plane_count

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
  count = var.control_plane_count

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

resource "oci_bastion_bastion" "talos" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  target_subnet_id = oci_core_subnet.bastion.id
  name             = "Talos"

  client_cidr_block_allow_list = ["0.0.0.0/0"]
}

# Talos API Load Balancer Access Bastion
resource "oci_bastion_session" "talos_session" {
  bastion_id             = oci_bastion_bastion.talos.id
  display_name           = "Port_Forward_Talos"
  session_ttl_in_seconds = 60 * 60 * 3

  key_details {
    public_key_content = var.ssh_public_key
  }

  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_private_ip_address = oci_network_load_balancer_network_load_balancer.talos.assigned_private_ipv4
    target_resource_port               = 50000
  }
}

# Kubernetes API Access
resource "oci_bastion_session" "k8s_api_session" {
  bastion_id             = oci_bastion_bastion.talos.id
  display_name           = "Port_Forward_K8S_API"
  session_ttl_in_seconds = 60 * 60 * 3

  key_details {
    public_key_content = var.ssh_public_key
  }
  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_private_ip_address = oci_network_load_balancer_network_load_balancer.talos.assigned_private_ipv4
    target_resource_port               = 6443
  }
}

# Public LBs SSH access for NixOS anywhere
resource "oci_bastion_session" "nixos_session" {
  count = var.loadbalancer_count

  bastion_id             = oci_bastion_bastion.talos.id
  display_name           = "Port_Forward_NixOS"
  session_ttl_in_seconds = 60 * 60 * 3

  key_details {
    public_key_content = var.ssh_public_key
  }
  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_private_ip_address = oci_core_instance.loadbalancers[count.index].private_ip
    target_resource_port               = 22
  }
}

/* Instances */
variable "talos_image_ocid" {
}

resource "oci_core_instance" "controlplane" {
  count = var.control_plane_count

  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "bom-talos-${count.index + 1}"
  shape               = var.instance_shape
  fault_domain        = "FAULT-DOMAIN-${count.index + 1}"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.nodes.id
    display_name     = "primaryvnic"
    assign_public_ip = false
    hostname_label   = "bom-talos-${count.index + 1}"
    private_ip       = "10.0.10.${count.index + 2}"
  }

  source_details {
    source_type = "image"
    source_id   = var.talos_image_ocid
  }

  metadata = {
    user_data = base64encode(data.talos_machine_configuration.this.machine_configuration)
  }
}

locals {
  loadbalancer_cloud_init = yamlencode({
    runcmd = [
      "curl -L https://github.com/nix-community/nixos-images/releases/latest/download/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | tar -xzf- -C /root",
      "/root/kexec/run"
    ]
  })
}

resource "oci_core_instance" "loadbalancers" {
  count = var.loadbalancer_count

  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "bom-loadbalancer-${count.index + 1}"
  shape               = var.loadbalancer_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.loadbalancer_memory
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_lbs.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "bom-loadbalancer-${count.index + 1}"

    private_ip    = "10.0.70.${count.index + 2}"
    assign_ipv6ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
    # boot_volume_size_in_gbs = 50
  }

  metadata = {
    user_data           = base64encode("#cloud-config\n${local.loadbalancer_cloud_init}")
    ssh_authorized_keys = var.ssh_public_key
  }
}

data "oci_core_images" "ubuntu" {
  compartment_id = var.compartment_ocid

  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04 Minimal aarch64"

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
  shape      = var.loadbalancer_shape
}
