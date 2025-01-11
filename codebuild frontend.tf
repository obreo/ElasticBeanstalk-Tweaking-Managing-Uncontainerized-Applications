# Reference doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/APIReference/API_Types.html
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
resource "aws_codebuild_project" "static" {
  count         = var.enable_frontend ? 1 : 0
  name          = "${var.name}-frontend"
  description   = "app on elastic beanstalk."
  build_timeout = 10
  service_role  = aws_iam_role.codebuild-elasticbeanstalk-role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # You can save time when your project builds by using a cache. A cache can store reusable pieces of your build environment and use them across multiple builds. 
  # Your build project can use one of two types of caching: Amazon S3 or local. 
  cache {
    type     = "S3"
    location = aws_s3_bucket.bucket.bucket
  }

  environment {
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
    compute_type = "BUILD_GENERAL1_SMALL"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html#environment.types
    # For Lmbda computes: Only available for environment type LINUX_LAMBDA_CONTAINER and ARM_LAMBDA_CONTAINER
    type = "LINUX_CONTAINER"
    # When you use a cross-account or private registry image, you must use SERVICE_ROLE credentials. When you use an AWS CodeBuild curated image, you must use CODEBUILD credentials.
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-log-group"
      stream_name = "codebuild-log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.bucket.id}/codebuild-build-log"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<EOF
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 20
  pre_build:
    commands:
      - echo 'calling parameters'
      - ${var.parameter_path != "" ? "aws ssm get-parameters-by-path --path ${var.parameter_path} --with-decryption --query 'Parameters[*].[Name,Value]' --output text | while read -r name value; do exported_variables='$${name##*/}=$value'; echo '$exported_variables' >> .env; done" : "echo no env stated."}
      - echo Installing source NPM dependencies... 
      - npm install
      - npm install -g @angular/cli
      - echo Dependecies installed.

  build:
    commands:
      - echo Build started 
      - ng build --configuration=production

  post_build:
    commands:
      - echo Uploading files to S3
      - aws s3 sync dist/ s3://${var.name}/ --delete
      - echo Files uplaoded to S3
      - echo Flushing Cloudfront cache
      - aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.static[count.index].id} --paths '/*'
    EOF
  }
}

