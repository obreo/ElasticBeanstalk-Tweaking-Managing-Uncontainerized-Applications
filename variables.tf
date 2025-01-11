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

# Beanstalk
# Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
variable "runtime_version" {
  description = "Choose the runtime as per AWS documentation"
  type        = string
  default     = "64bit Amazon Linux 2023 v6.4.1 running Node.js 20"
}
variable "LoadBalanced" {
  description = "True if load balanced envieonment."
  type        = bool
  default     = true
}
variable "instance_size" {
  description = "Minimum size and Maximum size | Required for LoadBalanced type"
  type        = list(string)
  default     = ["1", "1"]
}
variable "enable_cloudfront_singleInstance" {
  description = "True to Enable EB singleInstance behind cloudfront"
  type        = bool
  default     = false
}
variable "Keypair" {
  description = "KeyPair Name | Conflicts with `create_keypair`"
  type        = string
  default     = "test"
}
variable "create_keypair" {
  description = "Generate SSH key. Add the ssh.pub encryption | Conflicts with `Keypair`"
  type        = string
  default     = ""
}

# VPC
variable "create_vpc" {
  description = "If not enabled, then pass vpc details in custom_vpc_info"
  type        = bool
  default     = true
}
variable "custom_vpc_info" {
  description = "Fill the following VPC details for custom VPC"
  type = object({
    VPCId                      = string
    EBSubnets                  = string
    EBSecurityGroups           = string
    LoadBalancerSubnets        = list(string)
    LoadBalancerSecurityGroups = list(string)
    RDSSubnets                 = list(string)
    RDSSecurityGroups          = list(string)
  })
  default = {
    VPCId                      = ""
    EBSubnets                  = ""
    EBSecurityGroups           = ""
    LoadBalancerSubnets        = []
    LoadBalancerSecurityGroups = []
    RDSSubnets                 = []
    RDSSecurityGroups          = []
  }
}

# Permissions
variable "create_permissions" {
  description = "If flase, provide Beanstalk IAM Role, Instance Profile name"
  type = object({
    enable           = bool
    instance_profile = string
    eb_role          = list(string)
    codebuild_role   = string
  })
  default = {
    enable           = true
    eb_role          = ["<ARN>", "<NAME>"]
    instance_profile = "<NAME>"
    codebuild_role   = "<ARN>"
  }
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

# CloudFront
variable "enable_cloudfront" {
  description = "Enable CloudFront for Beanstalk - This will be managed for the development in Platfrom hook"
  type        = bool
  default     = true
}

# HTTPS
variable "enable_https" {
  description = "This will generate PostDeploy Hook that installs certbot on the instance"
  type        = bool
  default     = true
}

variable "domain" {
  description = "Set domain and subdomain for [Production , Development, Email]"
  type = list(string)
  default = [ "", "" , ""]
  
}

# Generate Frontend
variable "enable_frontend" {
  description = "Create S3 bucket with CloudFront and CD deployment for Frontend."
  type        = bool
  default     = true
}