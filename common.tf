terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.36.0"
    }
  }
}
# Providers 
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      owner_email = "${var.owner_email}"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.api_key # optionally use CONFLUENT_CLOUD_API_KEY env var
  cloud_api_secret = var.secret  # optionally use CONFLUENT_CLOUD_API_SECRET env var
}

# Random ids
resource "random_id" "aws" {
  byte_length = 4
}

resource "random_id" "confluent" {
  byte_length = 4
}

# Outputs
output "private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}
