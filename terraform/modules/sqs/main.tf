resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-analytics-queue-dlq"
  message_retention_seconds = 1209600 # 14 dias
}

resource "aws_sqs_queue" "events" {
  # Nome mantido igual ao usado pelos microsserviços na Fase 2
  # (AWS_SQS_URL em k8s/02-configmaps.yaml)
  name                       = "${var.project_name}-analytics-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Name = "${var.project_name}-events"
  }
}
