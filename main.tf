# Create ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "cluster_qs"
}
data "aws_ecs_task_definition" "latest" {
  task_definition = "td_MPulseQSInitial" # Replace with your task family name
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

# Create ECS Service
resource "aws_ecs_service" "service" {
  name            = "service_qs"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = data.aws_ecs_task_definition.latest.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-06ce45479d6e00d33"]
    security_groups = ["sg-082d38b7079abb377"]
    assign_public_ip = true 
  }
}
resource "aws_appautoscaling_policy" "scale_out_policy" {
  name               = "sqs-scale-out-policy"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 10
      scaling_adjustment          = 1
    }

    step_adjustment {
      metric_interval_lower_bound = 10
      metric_interval_upper_bound = 20
      scaling_adjustment          = 2
    }

    step_adjustment {
      metric_interval_lower_bound = 20
      metric_interval_upper_bound = 30
      scaling_adjustment          = 3
    }

    step_adjustment {
      metric_interval_lower_bound = 30
      scaling_adjustment          = 4
    }
  }
}
resource "aws_appautoscaling_policy" "scale_in_policy" {
  name               = "sqs-scale-in-policy"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment = -1
      metric_interval_upper_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_backlog_per_task_alarm" {
  alarm_name          = "sqs-backlog-per-task-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "sqs-backlog-per-task"
  namespace           = "CustomMetrics"
  period              = 60
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Alarm when SQS backlog per task is greater than 10"
  dimensions = {
    ServiceName = aws_ecs_service.service.name
    ClusterName = aws_ecs_cluster.cluster.name
  }

  actions_enabled = true
  alarm_actions   = [aws_appautoscaling_policy.scale_out_policy.arn]
  ok_actions      = [aws_appautoscaling_policy.scale_in_policy.arn]
}


resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
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

