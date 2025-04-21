variable "aws_region" {
  default = "us-east-1"
}

variable "aws_access_key" {
  default = "test"
}

variable "aws_secret_key" {
  default = "test"
}

variable "s3_endpoint" {
  default = "http://s3.localhost.localstack.cloud:4566"
}

variable "bucket_name" {
  default = "raw.datalake.mydomain.com"
}