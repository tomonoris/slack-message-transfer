variable "aws_region" {
  description = "AWS region for all resources."
  type = string
  default = "ap-northeast-1"
}

variable "slack_channel_to_send" {
  description = "Slack channel to send."
  type = string
}

variable "slack_token" {
  description = "Slack token to send."
  type = string
}