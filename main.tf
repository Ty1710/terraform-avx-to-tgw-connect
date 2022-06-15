data "aws_route53_zone" "pub" {
  name         = var.dns_zone
  private_zone = false
}

####  Aviatrix Components

module "aws_transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  cloud                         = "AWS"
  version                       = "2.1.1"
  account                       = var.aws_account_name
  region                        = var.aws_region
  cidr                          = "10.10.0.0/23"
  name                          = "awstransit"
  enable_advertise_transit_cidr = true
  instance_size                 = "c5n.4xlarge"
  insane_mode                   = true
  local_as_number               = var.avx_asn
#  bgp_ecmp                      = true
}

data "aviatrix_vpc" "aws_transit" {
  name                = module.aws_transit.vpc.name
  route_tables_filter = "public"
  depends_on = [
    module.aws_transit
  ]
}

resource "aws_route" "TrGW_route_to_TGW" {
  route_table_id         = data.aviatrix_vpc.aws_transit.route_tables[0]
  destination_cidr_block = "10.119.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  depends_on = [
    module.aws_transit,
    aws_ec2_transit_gateway.main
  ]
}


resource "aviatrix_transit_external_device_conn" "conn1" {
  vpc_id                    = module.aws_transit.transit_gateway.vpc_id
  connection_name           = "${var.env_name}-avx-to-tgw"
  gw_name                   = module.aws_transit.transit_gateway.gw_name
  connection_type           = "bgp"
  tunnel_protocol           = "GRE"
  ha_enabled                = true
  remote_gateway_ip         = aws_ec2_transit_gateway_connect_peer.peer1.transit_gateway_address
  backup_remote_gateway_ip  = aws_ec2_transit_gateway_connect_peer.peer2.transit_gateway_address
  bgp_local_as_num          = var.avx_asn
  bgp_remote_as_num         = var.tgw_asn
  backup_bgp_remote_as_num  = var.tgw_asn
  local_tunnel_cidr         = "${cidrhost(var.tunnel_cidr1, 1)}/29,${cidrhost(var.tunnel_cidr2, 4)}/29" 
  remote_tunnel_cidr        = "${cidrhost(var.tunnel_cidr1, 2)}/29,${cidrhost(var.tunnel_cidr2, 2)}/29" 
  backup_local_tunnel_cidr  = "${cidrhost(var.tunnel_cidr1, 4)}/29,${cidrhost(var.tunnel_cidr2, 1)}/29" 
  backup_remote_tunnel_cidr = "${cidrhost(var.tunnel_cidr1, 3)}/29,${cidrhost(var.tunnel_cidr2, 3)}/29" 
}

/* resource "aviatrix_transit_external_device_conn" "conn2" {
  vpc_id                    = module.aws_transit.transit_gateway.vpc_id
  connection_name           = "${var.env_name}-avx-to-tgw-2"
  gw_name                   = module.aws_transit.transit_gateway.gw_name
  connection_type           = "bgp"
  tunnel_protocol           = "GRE"
  ha_enabled                = true
  remote_gateway_ip         = aws_ec2_transit_gateway_connect_peer.peer3.transit_gateway_address
  backup_remote_gateway_ip  = aws_ec2_transit_gateway_connect_peer.peer4.transit_gateway_address
  bgp_local_as_num          = var.avx_asn
  bgp_remote_as_num         = var.tgw_asn
  backup_bgp_remote_as_num  = var.tgw_asn
  local_tunnel_cidr         = "${cidrhost(var.tunnel_cidr3, 1)}/29,${cidrhost(var.tunnel_cidr4, 4)}/29" 
  remote_tunnel_cidr        = "${cidrhost(var.tunnel_cidr3, 2)}/29,${cidrhost(var.tunnel_cidr4, 2)}/29" 
  backup_local_tunnel_cidr  = "${cidrhost(var.tunnel_cidr3, 4)}/29,${cidrhost(var.tunnel_cidr4, 1)}/29" 
  backup_remote_tunnel_cidr = "${cidrhost(var.tunnel_cidr3, 3)}/29,${cidrhost(var.tunnel_cidr4, 3)}/29" 
} */

module "spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud   = "AWS"
  version = "1.2.1"

  name          = "fra-spoke1"
  cidr          = "10.10.2.0/24"
  region        = var.aws_region
  account       = var.aws_account_name
  transit_gw    = module.aws_transit.transit_gateway.gw_name
  instance_size = "c5n.4xlarge"
  insane_mode   = true
}


####  Test Clients and Servers

module "aws1" {
  source        = "git::https://github.com/fkhademi/terraform-aws-instance-module.git"
  name          = "aws1"
  region        = var.aws_region
  vpc_id        = module.spoke1.vpc.vpc_id
  subnet_id     = module.spoke1.vpc.public_subnets[0].subnet_id
  ssh_key       = var.ssh_key
  public_ip     = true
  instance_size = "c5.xlarge"
  user_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int1",
      peer1 = "int3",
      peer2 = "int5"
  })
}

resource "aws_route53_record" "aws1" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "aws1.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws1.vm.public_ip]
}

resource "aws_route53_record" "int1" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int1.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws1.vm.private_ip]
}

module "aws2" {
  source        = "git::https://github.com/fkhademi/terraform-aws-instance-module.git"
  name          = "aws2"
  region        = var.aws_region
  vpc_id        = module.spoke1.vpc.vpc_id
  subnet_id     = module.spoke1.vpc.public_subnets[1].subnet_id
  ssh_key       = var.ssh_key
  public_ip     = true
  instance_size = "c5.xlarge"
  user_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int2",
      peer1 = "int4",
      peer2 = "int6"
  })
}

resource "aws_route53_record" "aws2" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "aws2.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws2.vm.public_ip]
}

resource "aws_route53_record" "int2" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int2.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws2.vm.private_ip]
}


## Azure

module "azure_transit" {
  source                        = "terraform-aviatrix-modules/mc-transit/aviatrix"
  cloud                         = "Azure"
  version                       = "2.1.1"
  account                       = var.azure_account_name
  region                        = var.azure_region
  cidr                          = "10.10.100.0/23"
  name                          = "azuretransit"
  enable_advertise_transit_cidr = true
  instance_size                 = "Standard_D5_v2"
  insane_mode                   = true
}

module "transit-peering" {
  source  = "terraform-aviatrix-modules/mc-transit-peering/aviatrix"
  version = "1.0.6"

  enable_insane_mode_encryption_over_internet = true
  tunnel_count                                = 8
  transit_gateways = [
    module.aws_transit.transit_gateway.gw_name,
    module.azure_transit.transit_gateway.gw_name
  ]
}


module "azure_spoke1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud   = "Azure"
  version = "1.2.1"

  name          = "azure-spoke1"
  cidr          = "10.10.102.0/24"
  region        = var.azure_region
  account       = var.azure_account_name
  transit_gw    = module.azure_transit.transit_gateway.gw_name
  instance_size = "Standard_D5_v2"
  insane_mode   = true
}

module "azure1" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-build-module.git?ref=for-ntttcp"

  name    = "azure-srv1"
  region  = var.azure_region
  rg      = module.azure_spoke1.vpc.resource_group
  vnet    = module.azure_spoke1.vpc.name
  subnet  = module.azure_spoke1.vpc.public_subnets[0].subnet_id
  ssh_key = var.ssh_key
  instance_size = "Standard_D5_v2"
  cloud_init_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int3",
      peer1 = "int1",
      peer2 = "int5"
  })
  public_ip = true
}

resource "aws_route53_record" "azure1" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "azure1.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure1.public_ip.ip_address]
}

resource "aws_route53_record" "int3" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int3.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure1.nic.private_ip_address]
}


module "azure2" {
  source = "git::https://github.com/fkhademi/terraform-azure-instance-build-module.git?ref=for-ntttcp"

  name    = "azure-srv2"
  region  = var.azure_region
  rg      = module.azure_spoke1.vpc.resource_group
  vnet    = module.azure_spoke1.vpc.name
  subnet  = module.azure_spoke1.vpc.public_subnets[1].subnet_id
  ssh_key = var.ssh_key
  instance_size = "Standard_D5_v2"
  cloud_init_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int4",
      peer1 = "int2",
      peer2 = "int6"
  })
  public_ip = true
}

resource "aws_route53_record" "azure2" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "azure2.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure2.public_ip.ip_address]
}

resource "aws_route53_record" "int4" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int4.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.azure2.nic.private_ip_address]
}