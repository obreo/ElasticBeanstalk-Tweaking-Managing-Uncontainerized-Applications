terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region                   = ""
  shared_config_files      = ["~/.aws/credentials"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = ""
}
