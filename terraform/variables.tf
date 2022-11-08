
variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Profile Account"
  default     = "default"
}

variable "env" {
  type        = string
  default = "dev"
}