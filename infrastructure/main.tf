terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

data "archive_file" "lambda_source" {
  source_dir = "../src"
  output_path = "source.zip"
  type        = "zip"
}

# TODO node_modules.zipをpackage.jsonから毎度いい感じに生成するshellスクリプトが必要
#data "archive_file" "node_modules_lambda_layer" {
#  source_dir = "../node_modules"
#  output_path = "node_modules.zip"
#  type        = "zip"
#}

resource "aws_lambda_layer_version" "slack_message_transfer" {
  layer_name = "node-modules-for-slack-message-transfer"
  filename = "../node_modules.zip"
  compatible_runtimes = ["nodejs14.x"]
}

resource "aws_s3_bucket" "lambda_source_bucket" {
  bucket = "slack-message-transfer-lambda-source-bucket"
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_source_bucket.id
  acl = "private"
}

resource "aws_s3_object" "lambda_source" {
  bucket = aws_s3_bucket.lambda_source_bucket.id
  key    = "source.zip"
  source = data.archive_file.lambda_source.output_path
  etag = filemd5(data.archive_file.lambda_source.output_path)
}

resource "aws_lambda_function" "slack_message_transfer" {
  function_name = "slack-message-transfer-v2"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_source_bucket.id
  s3_key = aws_s3_object.lambda_source.key

  layers = [aws_lambda_layer_version.slack_message_transfer.arn]

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda_source.output_base64sha256
}

resource "aws_cloudwatch_log_group" "slack_message_transfer_lambda" {
  name = "/aws/lambda/${aws_lambda_function.slack_message_transfer.function_name}"
  retention_in_days = 0
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role   = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "slack-message-transfer-api-gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id
  name   = "slack-message-transfer-api-gw-stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.slack_message_transfer_api_gw.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_apigatewayv2_integration" "slack_message_transfer" {
  api_id           = aws_apigatewayv2_api.lambda.id

  integration_uri = aws_lambda_function.slack_message_transfer.invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "slack_message_transfer" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "$default"
  target = "integrations/${aws_apigatewayv2_integration.slack_message_transfer.id}"
}

resource "aws_cloudwatch_log_group" "slack_message_transfer_api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 0
}

resource "aws_lambda_permission" "api_gw" {
  statement_id = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_message_transfer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}