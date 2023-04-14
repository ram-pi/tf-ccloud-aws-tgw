# Create simple VPC
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name    = "${var.owner}-tgw-example-vpc",
    "owner" = var.owner_email
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name    = "${var.owner}-tgw-example-igw",
    "owner" = var.owner_email
  }
}

data "aws_availability_zones" "non_local" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Create N private subnets
resource "aws_subnet" "private" {
  count                = 1
  vpc_id               = aws_vpc.main.id
  availability_zone_id = data.aws_availability_zones.non_local.zone_ids[count.index]
  cidr_block           = "10.1.${count.index}.0/24"
  tags = {
    Name    = "${var.owner}-tgw-example-subnet-private-${count.index}",
    "owner" = var.owner_email
  }
}

# Create N public subnets
resource "aws_subnet" "public" {
  count                = 1
  vpc_id               = aws_vpc.main.id
  availability_zone_id = data.aws_availability_zones.non_local.zone_ids[count.index]
  cidr_block           = "10.1.${100 + count.index}.0/24"
  tags = {
    Name    = "${var.owner}-tgw-example-subnet-public-${count.index}",
    "owner" = var.owner_email
  }
}

# Create route table for private subnets
resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id
  tags = {
    Name    = "${var.owner}-tgw-example-subnet-private-${count.index}-rt",
    "owner" = var.owner_email
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

# Create a route table for publics subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name    = "${var.owner}-tgw-example-subnet-public-rt",
    "owner" = var.owner_email
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route" "igw" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.igw.id
}

# Create nat gws stuff for private
# resource "aws_eip" "nat_gw" {
#   count = length(aws_subnet.private)
#   tags = {
#     Name = "tgw-example-subnet-private-${count.index}-nat-gw-eip"
#   }
# }

# resource "aws_nat_gateway" "nat_gw" {
#   count             = length(aws_subnet.private)
#   connectivity_type = "public"
#   allocation_id     = aws_eip.nat_gw[count.index].id
#   subnet_id         = aws_subnet.public[count.index].id
#   tags = {
#     Name = "tgw-example-subnet-private-${count.index}-nat-gw"
#   }
# }
# resource "aws_route" "nat_gw" {
#   count                  = length(aws_subnet.private)
#   destination_cidr_block = "0.0.0.0/0"
#   route_table_id         = aws_route_table.private[count.index].id
#   nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
# }

# Create private instances and related SGs
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "my_private_key" {
  depends_on = [
    tls_private_key.key
  ]
  content         = tls_private_key.key.private_key_pem
  filename        = "private.pem"
  file_permission = "0600"
}

resource "local_file" "my_public_key" {
  depends_on = [
    tls_private_key.key
  ]
  content         = tls_private_key.key.public_key_openssh
  filename        = "public.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "generate_key" {
  key_name = "${var.owner}-private-instance-key"
  #public_key = tls_private_key.key.public_key_openssh
  public_key = local_file.my_public_key.content
  tags = {
    Name    = "${var.owner}-tgw-example-private-instance-key",
    "owner" = var.owner_email
  }
}

# resource "aws_instance" "private" {
#   count                  = length(aws_subnet.private)
#   ami                    = data.aws_ami.amazon_linux.id
#   instance_type          = data.aws_ec2_instance_type.small.instance_type
#   key_name               = aws_key_pair.generate_key.key_name
#   subnet_id              = aws_subnet.private[count.index].id
#   vpc_security_group_ids = aws_security_group.private_instance_ssh.*.id
#   tags = {
#     Name    = "tgw-example-private-instance-${count.index}",
#     "owner" = var.owner_email
#   }
# }

# resource "aws_security_group" "private_instance_ssh" {
#   count  = length(aws_subnet.private)
#   vpc_id = aws_vpc.main.id
#   name   = "tgw-example-private-instance-${count.index}-sg"
#   egress {
#     description = "Allow all outbound"
#     from_port   = 0
#     to_port     = 0
#     protocol    = -1
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   ingress {
#     description = "SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["10.1.${100 + count.index}.0/24"]
#   }
#   ingress {
#     description = "PING"
#     from_port   = -1
#     to_port     = -1
#     protocol    = "icmp"
#     cidr_blocks = ["${aws_vpc.main.cidr_block}"]
#   }
#   tags = {
#     Name = "tgw-example-private-instance-${count.index}-sg"
#   }
# }

# Find instance ami and type
data "aws_ami" "ubuntu" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Create bastion instances and related sgs
resource "aws_instance" "bastion" {
  count                       = length(aws_subnet.public)
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  #instance_type               = data.aws_ec2_instance_type.small.instance_type
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.generate_key.key_name
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  tags = {
    Name    = "${var.owner}-tgw-example-bastion-instance-${count.index}",
    "owner" = var.owner_email
  }
}

# Capture the current public ip of the machine running this
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

# Gather all the service ips from aws
data "http" "ec2_instance_connect" {
  url = "https://ip-ranges.amazonaws.com/ip-ranges.json"
}

# Specifically get the ec2 instance connect service ip so it can be whitelisted
locals {
  ec2_instance_connect_ip = [for e in jsondecode(data.http.ec2_instance_connect.response_body)["prefixes"] : e.ip_prefix if e.region == "${var.aws_region}" && e.service == "EC2_INSTANCE_CONNECT"]
}

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.main.id
  name   = "${var.owner}-tgw-example-bastion-instance-sg"
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.ec2_instance_connect_ip[0]}", "${chomp(data.http.myip.response_body)}/32"]
  }
  ingress {
    description = "PING"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${aws_vpc.main.cidr_block}"]
  }
  tags = {
    Name = "tgw-example-bastion-instance-sg"
  }
}
