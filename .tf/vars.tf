variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC ID"
}

variable "ssh_key" {
  type        = string
  default     = ""
  description = "SSH Key Pair Name"
}

variable "subnet_ids" {
  type        = list(string)
  default     = [""]
  description = ""
}