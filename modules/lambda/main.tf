resource "aws_lambda_function" "data_processor" {
  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  function_name    = "data_processor"
  role             = var.lambda_exec_role_arn
  handler          = "index.handler"
  runtime          = var.nodejs_runtime

  environment {
    variables = {
      RDS_ENDPOINT = var.rds_endpoint
      SQS_QUEUE_URL = var.sqs_queue_url
    }
  }
}


resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_lambda_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}