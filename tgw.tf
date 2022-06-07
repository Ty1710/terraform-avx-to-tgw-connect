locals {
  vpc_rt_to_tgw = [
    {
      cidr_block = "10.0.0.0/8"
      tgw_id     = aws_ec2_transit_gateway.main.id
    },
    {
      cidr_block = "172.16.0.0/12"
      tgw_id     = aws_ec2_transit_gateway.main.id
    },
    {
      cidr_block = "192.168.0.0/16"
      tgw_id     = aws_ec2_transit_gateway.main.id
    }
  ]
}

locals {
  underlay_subnets_to_attach = tolist([
    for subnet in module.aws_transit.vpc.public_subnets :
    subnet.subnet_id if length(regexall("mgmt", subnet.name)) > 0
  ])
}

## TGW

resource "aws_ec2_transit_gateway" "main" {
  description     = "${var.env_name}-tgw"
  amazon_side_asn = var.tgw_asn
  transit_gateway_cidr_blocks = [var.tgw_cidr]
  tags = {
    "Name" = "${var.env_name}-tgw"
  }
}

resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = {
    Name = "${var.env_name}-avx-underlay"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "rt1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-to-avx.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propagation1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-to-avx.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propagation2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_connect.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-to-avx" {
  subnet_ids                                      = local.underlay_subnets_to_attach
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = module.aws_transit.transit_gateway.vpc_id
  transit_gateway_default_route_table_association = false
  tags = {
    Name = "${var.env_name}-avx-transit-attachment"
  }
}

resource "aws_ec2_transit_gateway_connect" "main" {
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw-to-avx.id
  transit_gateway_id      = aws_ec2_transit_gateway.main.id
  tags = {
    "Name" = "${var.env_name}-tgw-connect-attachment"
  }
}

resource "aws_ec2_transit_gateway_connect_peer" "peer1" {
  peer_address = module.aws_transit.transit_gateway.private_ip
  bgp_asn      = var.avx_asn
  inside_cidr_blocks            = [var.tunnel_cidr1]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.main.id
  tags = {
    "Name" = "${var.env_name}-tgw-connect-peer1"
  }
}

resource "aws_ec2_transit_gateway_connect_peer" "peer2" {
  peer_address = module.aws_transit.transit_gateway.ha_private_ip
  bgp_asn      = var.avx_asn
  inside_cidr_blocks            = [var.tunnel_cidr2]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.main.id
  tags = {
    "Name" = "${var.env_name}-tgw-connect-peer2"
  }
}

## Testing additional tunnels

resource "aws_ec2_transit_gateway_connect_peer" "peer3" {
  peer_address = module.aws_transit.transit_gateway.private_ip
  bgp_asn      = var.avx_asn
  inside_cidr_blocks            = [var.tunnel_cidr3]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.main.id
  tags = {
    "Name" = "${var.env_name}-tgw-connect-peer3"
  }
}

resource "aws_ec2_transit_gateway_connect_peer" "peer4" {
  peer_address = module.aws_transit.transit_gateway.ha_private_ip
  bgp_asn      = var.avx_asn
  inside_cidr_blocks            = [var.tunnel_cidr4]
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.main.id
  tags = {
    "Name" = "${var.env_name}-tgw-connect-peer4"
  }
}

### Spoke VPC

resource "aws_vpc" "spoke1" {
  cidr_block       = "10.92.0.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "aws-tgw-spoke1"
  }
}

resource "aws_subnet" "spoke1" {
  vpc_id     = aws_vpc.spoke1.id
  cidr_block = "10.92.0.0/28"

  tags = {
    Name = "spoke1-sub-0"
  }
}

resource "aws_internet_gateway" "spoke1" {
  vpc_id = aws_vpc.spoke1.id
}

resource "aws_route_table" "spoke1" {
  vpc_id = aws_vpc.spoke1.id

  dynamic "route" {
    for_each = local.vpc_rt_to_tgw
    content {
      cidr_block         = route.value.cidr_block
      transit_gateway_id = route.value.tgw_id
    }
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spoke1.id
  }
  tags = {
    Name = "spoke1-rtb"
  }
}

resource "aws_route_table_association" "spoke1" {
  subnet_id      = aws_subnet.spoke1.id
  route_table_id = aws_route_table.spoke1.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke1" {
  subnet_ids                                      = [aws_subnet.spoke1.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = aws_vpc.spoke1.id
  transit_gateway_default_route_table_association = false
  tags = {
    Name = "spoke1-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}



module "aws3" {
  source        = "git::https://github.com/fkhademi/terraform-aws-instance-module.git"
  name          = "aws3"
  region        = var.aws_region
  vpc_id        = aws_vpc.spoke1.id
  subnet_id     = aws_subnet.spoke1.id
  ssh_key       = var.ssh_key
  public_ip     = true
  instance_size = "c5.xlarge"
  user_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int5",
      peer1 = "int1",
      peer2 = "int3"
  })
}

resource "aws_route53_record" "aws3" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "aws3.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws3.vm.public_ip]
}

resource "aws_route53_record" "int5" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int5.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws3.vm.private_ip]
}

module "aws4" {
  source        = "git::https://github.com/fkhademi/terraform-aws-instance-module.git"
  name          = "aws4"
  region        = var.aws_region
  vpc_id        = aws_vpc.spoke1.id
  subnet_id     = aws_subnet.spoke1.id
  ssh_key       = var.ssh_key
  public_ip     = true
  instance_size = "c5.xlarge"
  user_data = templatefile("${path.module}/cloud-init.tpl",
    {
      name  = "int6",
      peer1 = "int2",
      peer2 = "int4"
  })
}

resource "aws_route53_record" "aws4" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "aws4.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws4.vm.public_ip]
}

resource "aws_route53_record" "int6" {
  zone_id = data.aws_route53_zone.pub.zone_id
  name    = "int6.${data.aws_route53_zone.pub.name}"
  type    = "A"
  ttl     = "1"
  records = [module.aws4.vm.private_ip]
}