variable "loadbalancer_count" {
  default     = 1
  description = "Number of load balancer VMs"
}

variable "loadbalancer_memory" {
  default     = 2
  description = "Load balancer memory in GB"
}

variable "loadbalancer_shape" {
  default = "VM.Standard.E4.Flex"
}
