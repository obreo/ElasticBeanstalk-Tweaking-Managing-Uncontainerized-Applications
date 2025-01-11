# Create an S3 bucket for the frontend - static site
resource "aws_s3_bucket" "static" {
  count         = var.enable_frontend ? 1 : 0
  bucket        = "${var.name}-frontend"
  force_destroy = true
}


# Disable bucket ACLs to allow bucket policy
resource "aws_s3_bucket_ownership_controls" "static" {
  count         = var.enable_frontend ? 1 : 0
  bucket = aws_s3_bucket.static[count.index].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
/*
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

*/
# Bucket policy
resource "aws_s3_bucket_policy" "static" {
  count  = var.enable_frontend ? 1 : 0
  bucket = aws_s3_bucket.static[count.index].id
  policy = data.aws_iam_policy_document.static[0].json
}


data "aws_iam_policy_document" "static" {
  count = var.enable_frontend ? 1 : 0
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.static[0].arn,
      "${aws_s3_bucket.static[0].arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.static[0].arn]
    }
  }
}
