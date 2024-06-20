variable "ecs_cluster_name" {
  type    = string
  default = "td-sqs-trigger"  # Replace with your ECS cluster name or provide as input
}

variable "ecs_service_name" {
  type    = string
  default = "td-sqs-trigger"  # Replace with your ECS service name or provide as input
}
