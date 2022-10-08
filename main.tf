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
  source_dir = "${path.module}/src"
  output_path = "${path.module}/source.zip"
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