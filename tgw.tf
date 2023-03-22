
# Create transit gateway 
resource "aws_ec2_transit_gateway" "main" {
  description = "tgw-${random_id.aws.hex}"
  tags = {
    Name    = "tgw-example",
    "owner" = var.owner_email
  }
}
# Configure ram share
resource "aws_ram_resource_share" "confluent" {
  name                      = "resource-share-with-confluent-${random_id.aws.hex}"
  allow_external_principals = true

}
resource "aws_ram_principal_association" "confluent" {
  principal          = confluent_network.tgw.aws[0].account
  resource_share_arn = aws_ram_resource_share.confluent.arn
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.confluent.arn
}

# Find and set to auto-accept the transit gateway attachment from Confluent
data "aws_ec2_transit_gateway_vpc_attachment" "accepter" {
  id = confluent_transit_gateway_attachment.main.aws[0].transit_gateway_attachment_id
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "accepter" {
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_vpc_attachment.accepter.id
}

# Create an attachment for the peer, AWS, VPC to the transit gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  subnet_ids         = aws_subnet.private.*.id
  vpc_id             = aws_vpc.main.id
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

# Create routes from the subnets to the transit gateway CIDR
resource "aws_route" "tgw" {
  count                  = length(aws_subnet.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = confluent_network.tgw.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

# resource "aws_route" "tgw_public" {
#   count                  = length(aws_subnet.public)
#   route_table_id         = aws_route_table.public[count.index].id
#   destination_cidr_block = confluent_network.tgw.cidr
#   transit_gateway_id     = aws_ec2_transit_gateway.main.id
# }

data "aws_subnet_ids" "input" {
  vpc_id = aws_vpc.main.id
}

# Find the routing table
data "aws_route_tables" "rts" {
  vpc_id = data.aws_subnet_ids.input.vpc_id
}

resource "aws_route" "r" {
  for_each               = toset(data.aws_route_tables.rts.ids)
  route_table_id         = each.key
  destination_cidr_block = confluent_network.tgw.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}
