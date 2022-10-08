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

resource "aws_lambda_function" "slack-message-transfer" {
  function_name = "slack-message-transfer-managed-by-terraform"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_source_bucket.id
  s3_key = aws_s3_object.lambda_source.key

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda_source.output_base64sha256
}

resource "aws_cloudwatch_log_group" "slack-message-transfer" {
  name = "/aws/lambda/${aws_lambda_function.slack-message-transfer.function_name}"
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
