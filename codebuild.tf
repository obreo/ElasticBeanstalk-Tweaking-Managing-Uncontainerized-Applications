# Reference doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/APIReference/API_Types.html
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
resource "aws_codebuild_project" "project" {
  name          = "${var.name}-nodejs-elasticebanstalk"
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
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
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
    # This is a buildspec script that will build the nodejs source, compress it and uplode it to s3 bucket, then update the elastic beanstalk environment with it.
    # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
    version: 0.2
        env:
          variables:
            S3_BUCKET: "${aws_s3_bucket.bucket.bucket}"
            S3_FOLDER: ""
            ZIP_FILE_NAME: "${var.name}"
            EB_APP: "${aws_elastic_beanstalk_application.application.name}"
            EB_ENV: "${aws_elastic_beanstalk_environment.environment.name}"

        phases:
          install:
            runtime-versions:
              nodejs: 20
          pre_build:
            commands:
              - echo Calling environment variables using SSM Parameters for building..
              - while read -r name value; do export_string="$${name##*/}=$value"; export "$export_string"; done < <(aws ssm get-parameters-by-path --path "${var.parameter_path}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
              - echo Injecting .Platform Hook directory file to call SSM path as an alternative to the environment properties - for envionments that require to be running during runtime.
              - sed -i 's|{PARAMETERS_PATH}|${var.parameter_path}|g' ./.platfrom/hooks/predeploy/environment_properties.sh
              - npm install -f
          build:
            commands:
              - echo Compiling..
              - npm run build
              - find . -type f -exec zip $${ZIP_FILE_NAME}.zip {} +
              - echo Pushing ZIP artifacts to S3 bucket
              - aws s3 cp $${ZIP_FILE_NAME}.zip s3://$${S3_BUCKET}/$${S3_FOLDER}/$${ZIP_FILE_NAME}.zip
              - echo Creating a new Elastic Beanstalk version with the new build file.
              - aws elasticbeanstalk create-application-version --application-name $${EB_APP} --version-label $${CODEBUILD_BUILD_NUMBER} --source-bundle S3Bucket=$${S3_BUCKET},S3Key=$${S3_FOLDER}/$${ZIP_FILE_NAME}.zip
              - echo Updating the Elastic Beanstalk environment.
              - aws elasticbeanstalk update-environment --environment-name $${EB_ENV} --version-label $${CODEBUILD_BUILD_NUMBER}
    EOF
  }
}

