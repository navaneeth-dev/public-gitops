terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.0"
    }

    oci = {
      source  = "oracle/oci"
      version = "6.37.0"
    }
  }
}

provider "talos" {
}

// Oracle
variable "user_ocid" {
}

variable "fingerprint" {
}

variable "tenancy_ocid" {
}

variable "region" {
  default = "ap-mumbai-1"
}

variable "private_key_path" {
  default = ""
}

variable "compartment_ocid" {
}

provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}
