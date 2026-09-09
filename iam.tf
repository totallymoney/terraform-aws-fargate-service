# Two roles, and the difference matters.
#
#   execution role: used by ECS itself to pull the image, write logs and fetch
#                   the secrets listed in the task definition.
#   task role:      used by your application code at runtime.
#
# Putting application permissions on the execution role is a common mistake. It
# widens what a compromised container can do, because the container can reach
# the task role but should not be able to act as the platform.

locals {
  # Secrets Manager ARNs can carry a JSON key and version suffix. IAM needs the
  # secret ARN on its own, so trim anything after the sixth colon field.
  secret_arns = distinct([
    for s in var.secrets :
    length(split(":", s.valueFrom)) > 7
    ? join(":", slice(split(":", s.valueFrom), 0, 7))
    : s.valueFrom
  ])

  ssm_secret_arns            = [for a in local.secret_arns : a if split(":", a)[2] == "ssm"]
  secretsmanager_secret_arns = [for a in local.secret_arns : a if split(":", a)[2] == "secretsmanager"]

  ecr_pull_resources = var.create_ecr_repository ? [aws_ecr_repository.this[0].arn] : ["*"]
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Stops another account persuading ECS to assume this role on its behalf.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "execution" {
  # GetAuthorizationToken takes no resource, so it cannot be narrowed.
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = local.ecr_pull_resources
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.container.arn}:*"]
  }

  dynamic "statement" {
    for_each = length(local.ssm_secret_arns) > 0 ? [1] : []

    content {
      sid       = "ReadParameters"
      actions   = ["ssm:GetParameters"]
      resources = local.ssm_secret_arns
    }
  }

  dynamic "statement" {
    for_each = length(local.secretsmanager_secret_arns) > 0 ? [1] : []

    content {
      sid       = "ReadSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.secretsmanager_secret_arns
    }
  }

  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []

    content {
      sid       = "DecryptWithModuleKey"
      actions   = ["kms:Decrypt"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.tags
}

# Empty until you give it something. A task role with no policy is the right
# starting point.
resource "aws_iam_role_policy" "task" {
  count = var.task_role_policy_json != null ? 1 : 0

  name   = "task"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy_json
}

# execute-command needs these on the task role, not the execution role.
resource "aws_iam_role_policy" "task_exec_command" {
  count = var.enable_execute_command ? 1 : 0

  name = "execute-command"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups"]
        Resource = "${aws_cloudwatch_log_group.exec[0].arn}:*"
      },
    ]
  })
}
