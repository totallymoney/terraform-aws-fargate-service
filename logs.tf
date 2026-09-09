resource "aws_cloudwatch_log_group" "container" {
  name              = "/aws/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = local.tags
}

# Every execute-command session is recorded here. This is the audit trail for
# anyone who opens a shell in a running task.
resource "aws_cloudwatch_log_group" "exec" {
  count = var.enable_execute_command ? 1 : 0

  name              = "/aws/ecs/${var.name}/exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = local.tags
}
