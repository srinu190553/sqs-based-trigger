
# Create SQS Queue
resource "aws_sqs_queue" "queue" {
  name = "my-sqs-queue"
}

# Create DynamoDB Table
resource "aws_dynamodb_table" "table" {
  name           = "my-dynamodb-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# Create ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "my-cluster"
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "my-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "my-container"
    image = "933085737869.dkr.ecr.us-east-1.amazonaws.com/my-sqs-dynamodb-app:latest"
    essential = true
    environment = [
      {
        name = "SQS_QUEUE_URL"
        value = aws_sqs_queue.queue.id
      },
      {
        name = "DYNAMODB_TABLE_NAME"
        value = aws_dynamodb_table.table.name
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"        = "/ecs/my-task"
        "awslogs-region"       = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# Create ECS Service
resource "aws_ecs_service" "service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-06ce45479d6e00d33"]
    security_groups = ["sg-082d38b7079abb377"]
    assign_public_ip = "ENABLED"
  }
}

# Create CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "my-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 6,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/SQS", "NumberOfMessagesReceived", "QueueName", aws_sqs_queue.queue.name ],
            [ "AWS/DynamoDB", "PutItem", "TableName", aws_dynamodb_table.table.name ]
          ],
          period = 300,
          stat = "Sum",
          region = "us-east-1",
          title = "Messages Processed and Items Created"
        }
      }
    ]
  })
}

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Create Target Tracking Scaling Policy
resource "aws_appautoscaling_policy" "ecs_service_target_tracking" {
  name               = "ecs-service-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 10.0

    customized_metric_specification {
      metrics {
        label = "Get the queue size (the number of messages waiting to be processed)"
        id    = "m1"

        metric_stat {
          metric {
            metric_name = "ApproximateNumberOfMessagesVisible"
            namespace   = "AWS/SQS"

            dimensions {
              name  = "QueueName"
              value = aws_sqs_queue.queue.name
            }
          }

          stat = "Sum"
        }

        return_data = false
      }

      metrics {
        label = "Get the ECS running task count (the number of currently running tasks)"
        id    = "m2"

        metric_stat {
          metric {
            metric_name = "RunningTaskCount"
            namespace   = "ECS/ContainerInsights"

            dimensions {
              name  = "ClusterName"
              value = aws_ecs_cluster.cluster.name
            }

            dimensions {
              name  = "ServiceName"
              value = aws_ecs_service.service.name
            }
          }

          stat = "Average"
        }

        return_data = false
      }

      metrics {
        label       = "Calculate the backlog per instance"
        id          = "e1"
        expression  = "m1 / m2"
        return_data = true
      }
    }

    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_iam_role" "ecs_autoscaling_role" {
  name = "ecs-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "application-autoscaling.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_autoscaling_policy" {
  role       = aws_iam_role.ecs_autoscaling_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}


# Output the SQS Queue URL
output "sqs_queue_url" {
  value = aws_sqs_queue.queue.id
}

# Output the DynamoDB Table Name
output "dynamodb_table_name" {
  value = aws_dynamodb_table.table.name
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.task.arn
}

