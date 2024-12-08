resource "aws_api_gateway_rest_api" "api" {
  name        = "LinkuyConnectAPI"
  description = "API Gateway for LinkuyConnect"
}

resource "aws_api_gateway_resource" "activity" {
  parent_id = aws_api_gateway_rest_api.api.root_resource_id
  path_part = "activity"
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_method" "post_activity" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.activity.id
  api_key_required = true
  authorization    = "AWS_IAM"  
  http_method   = "POST"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  description = "Deployment for production"
}

resource "aws_api_gateway_stage" "production" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name = "prod"
}
