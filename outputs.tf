output "bastion_public_ip" {
  value = aws_instance.bastion[*].public_ip
}

output "bootstrap" {
  value = confluent_kafka_cluster.dedicated.bootstrap_endpoint
}

output "kafka_api_key" {
  value = confluent_api_key.kafka-api-key.id
}

output "kafka_api_key_secret" {
  value     = confluent_api_key.kafka-api-key.secret
  sensitive = true
}

# output "private_instance_internal_ip" {
#   value = aws_instance.private[*].private_ip
# }
