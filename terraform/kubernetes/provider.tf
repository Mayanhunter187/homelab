locals {
  aws_region = "us-east-2"
}

#Creds are handled by ~/.aws/credentials file setup with AWS CLI command aws configure
provider "aws" {
  region = local.aws_region
}

data "aws_caller_identity" "current_id" {}

data "aws_ssm_parameter" "pve_endpoint" {
  name = "/homelab/proxmox/endpoint"
}

ephemeral "aws_ssm_parameter" "pve_token" {
  arn             = "arn:aws:ssm:${local.aws_region}:${data.aws_caller_identity.current_id.account_id}:parameter/homelab/proxmox/api-token"
  with_decryption = true
}

provider "proxmox" {
  endpoint  = data.aws_ssm_parameter.pve_endpoint.value
  api_token = ephemeral.aws_ssm_parameter.pve_token.value
}
