# Environment 
data "confluent_environment" "main" {
  id = var.env
}

data "confluent_service_account" "cc_sa" {
  id = var.service_account
}

# Create the network for the tgw
resource "confluent_network" "tgw" {
  display_name     = "${var.owner}-tgw-network-${random_id.confluent.hex}"
  cloud            = "AWS"
  region           = var.aws_region
  cidr             = "10.10.0.0/16"
  zones            = slice(data.aws_availability_zones.non_local.zone_ids, 0, 3)
  connection_types = ["TRANSITGATEWAY"]
  environment {
    id = data.confluent_environment.main.id
  }
}

# Create the tgw attachment
resource "confluent_transit_gateway_attachment" "main" {
  display_name = "${var.owner}-tgw-attachment-${random_id.confluent.hex}"
  aws {
    ram_resource_share_arn = aws_ram_resource_share.confluent.arn
    transit_gateway_id     = aws_ec2_transit_gateway.main.id
    routes                 = ["10.1.0.0/16"]
  }
  environment {
    id = data.confluent_environment.main.id
  }
  network {
    id = confluent_network.tgw.id
  }
}

# Provision the cluster in the network
resource "confluent_kafka_cluster" "dedicated" {
  display_name = "${var.owner}-dedicated-tgw"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.aws_region
  dedicated {
    cku = 1
  }
  environment {
    id = data.confluent_environment.main.id
  }
  network {
    id = confluent_network.tgw.id
  }
}

resource "confluent_api_key" "kafka-api-key" {
  display_name = "tf-kafka-api-key"
  description  = "tf-kafka-api-key"

  disable_wait_for_ready = true

  # Set optional `disable_wait_for_ready` attribute (defaults to `false`) to `true` if the machine where Terraform is not run within a private network
  # disable_wait_for_ready = true

  owner {
    id          = data.confluent_service_account.cc_sa.id
    api_version = data.confluent_service_account.cc_sa.api_version
    kind        = data.confluent_service_account.cc_sa.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind

    environment {
      id = data.confluent_environment.main.id
    }
  }
}
