variable "region" {
  description = "AWS Region for all resources."
  type        = string
  default     = "ap-south-1"
}

variable "student_name" {
  description = "Your name, used for the Student tag."
  type        = string
}

variable "my_ip_cidr" {
  description = "Your current public IPv4 as a /32 (e.g. 203.0.113.25/32). Used for bastion SSH."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && endswith(var.my_ip_cidr, "/32") && var.my_ip_cidr != "0.0.0.0/32"
    error_message = "Provide your own public IPv4 as a /32. Do not open SSH to 0.0.0.0/0."
  }
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair (created in the console, .pem kept on your laptop)."
  type        = string
  default     = "ewb-lab"
}

variable "instance_type" {
  description = "Small x86 instance type. Check pricing and credits first."
  type        = string
  default     = "t3.micro"
}

variable "enable_peering" {
  description = "Set false for the baseline test (no peering, no peer routes). Set true to connect the VPCs."
  type        = bool
  default     = true
}

variable "enable_app_b_icmp_rule" {
  description = "Set false for the controlled failure test (removes App-B ICMP echo rule). Set true to restore."
  type        = bool
  default     = true
}
