variable "controller_ip" {
  type        = string
  description = "Aviatrix Controller IP or FQDN"
}

variable "username" {
  type        = string
  description = "Aviatrix Controller Username"
  default     = "admin"
}

variable "password" {
  type        = string
  description = "Aviatrix Controller Password"
}

variable "dns_zone" {
  type        = string
  default     = "avxlab.de"
  description = "Route53 Domain Name to update"
}

variable "aws_account_name" {
  type        = string
  description = "AWS Account Name"
  default     = "aws"
}

variable "azure_account_name" {
  type        = string
  description = "Azure Account Name"
  default     = "azure-sub-1"
}

variable "gcp_account_name" {
  type        = string
  description = "GCP Account Name"
  default     = "gcp-acct-1"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-central-1"
}

variable "azure_region" {
  type        = string
  description = "Azure Region"
  default     = "West Europe"
}

variable "gcp_region" {
  type        = string
  description = "GCP Region"
  default     = "europe-west3"
}

variable "ssh_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnNDeCuEOgJjtFFzWa9fXyKj8mSdCnCVR+iOm40JYSO4/kKEOflq0VvtIcnezv1wa4Ghj3RqEcFd9857qAQfqsn5KgjwuoYG37eTthz9waKSbem6l8hilR4CncagBqMqje8EDuWFdyNPWmgM04nHJ+HRn0UoXzYikSbbQJ082XORREEpZA4Rt7ZHtIncqN5EMBPQ4lflDOR7l0pCTcGObHNPOuWje35ZQqcjryskUkgvEzx+kFxnJ5fG2cwvDkoq8JrCwXhZNmoYNvR6cAtzMo7S/v7THxCxYMgsSUWRzY1+Pi93EB/CIZp5le0gewblrzXpc8DmHd5NPi3ObPwPTh dennis@NUC"
}

variable "avx_asn" {
  default = 65001
}

variable "tgw_asn" {
  default = 64512
}

variable "tgw_cidr" {
  default = "10.119.0.0/16"
}

variable "tunnel_cidr1" {
  default = "169.254.100.0/29"
}

variable "tunnel_cidr2" {
  default = "169.254.200.0/29"
}

variable "tunnel_cidr3" {
  default = "169.254.210.0/29"
}

variable "tunnel_cidr4" {
  default = "169.254.220.0/29"
}

variable "env_name" {
  default = "demo"
}