variable "ami" {
  description = "The AMI to use for the Mender environment instance."
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Ubuntu 20.04 LTS
}

variable "instance_type" {
  description = "The instance type to use for the Mender environment instance."
  type        = string
  default     = "t2.micro"
}
