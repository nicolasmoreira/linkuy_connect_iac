output "lambda_arn" {
  value = aws_lambda_function.data_processor.arn
}

output "lambda_exec_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}
