resource "aws_kinesis_stream" "data_stream" {
  name = "linkuyconnect-activity-stream"
  shard_count = 1
}

resource "aws_iam_role_policy_attachment" "kinesis_consumer_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
  role       = var.lambda_exec_role_arn
}