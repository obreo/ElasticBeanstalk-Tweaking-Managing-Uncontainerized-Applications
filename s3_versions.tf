# Create an S3 bucket where the application's zip file shall be stored.
resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.name}.bucket"
  force_destroy = true
}

# Upload file to s3 bucket
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.bucket.id
  # Directory file in S3 Bucket
  key = "beanstalk/nodejs.zip" # This is a sample app, the actual application will be deployed using CICD
  # Local file source
  source = "source/nodejs.zip"
}


# Disable bucket ACLs to allow bucket policy
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

/*
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
*/
# Bucket policy
resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
  statement {
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "codepipeline.amazonaws.com",
        "elasticbeanstalk.amazonaws.com",
        "codebuild.amazonaws.com",
        "cloudformation.amazonaws.com"
      ]
    }

    actions = [
      "s3:PutObjectAcl",
      "s3:PutObject",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:AbortMultipartUpload"
    ]

    resources = [
      "${aws_s3_bucket.bucket.arn}",
      "${aws_s3_bucket.bucket.arn}/*"
    ]
  }
}

