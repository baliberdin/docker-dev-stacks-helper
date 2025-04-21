provider "aws" {
  region                      = var.aws_region
  access_key                 = var.aws_access_key
  secret_key                 = var.aws_secret_key
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  endpoints {
    s3 = var.s3_endpoint
  }
}

resource "aws_s3_bucket" "datalake" {
  bucket = var.bucket_name
  force_destroy = true
}