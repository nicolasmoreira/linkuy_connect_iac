output "api_gateway_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}

output "invoke_url" {
  value = aws_api_gateway_stage.production.invoke_url
}
