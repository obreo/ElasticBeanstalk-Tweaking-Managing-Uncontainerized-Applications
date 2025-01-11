# Create Origin Access Control
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  count                             = var.enable_frontend ? 1 : 0
  name                              = var.name
  description                       = "Cloud Front OAC for S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

