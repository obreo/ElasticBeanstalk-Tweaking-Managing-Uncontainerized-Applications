# Cloud Settings
variable "account_id" {
  description = "aws account id"
  type        = string
  default     = ""
}
variable "region" {
  description = "aws region"
  type        = string
  default     = ""
}

# Application settings
variable "name" {
  description = "application name"
  type        = string
  default     = ""
}
variable "instance_type" {
  description = "launch configuration instance type"
  type        = string
  default     = "t2.micro"
}
variable "ssh-key" {
  description = "public ssh key for instance access"
  type        = string
  default     = ""
}


# RDS
variable "rds_port" {
  description = "If any"
  type        = number
  default     = 0
}
variable "username" {
  description = "instance username"
  type        = string
  sensitive   = true
  default     = ""
}
variable "password" {
  description = "instance password"
  type        = string
  sensitive   = true
  default     = ""
}

# SSM Parameters
variable "parameter_path" {
  description = "ssm parameters path"
  type        = string
  sensitive   = false
  default     = ""
}