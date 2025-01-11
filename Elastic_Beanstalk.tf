# Elastic beanstalk environment - SingleInstance type

# Elastic beanstalk version
resource "aws_elastic_beanstalk_application_version" "version" {
  name        = var.name
  application = aws_elastic_beanstalk_application.application.name
  description = "application version"
  bucket      = aws_s3_bucket.bucket.id
  key         = aws_s3_object.object.id
  lifecycle {
    ignore_changes = [
      bucket, # Ignore changes to the bucket source
      key,    # Ignore changes to the key source
      name    # Ignore changes to the version name
    ]
  }
}

# Elastic beanstalk app
resource "aws_elastic_beanstalk_application" "application" {
  name        = var.name
  description = "Running ${var.name}"
  appversion_lifecycle {
    service_role          = var.create_permissions.enable ? aws_iam_role.elasticbeanstalk_service_role.arn : var.create_permissions.eb_role[0]
    max_count             = 3
    delete_source_from_s3 = "true"
  }
}

# Elastic beanstalk env
resource "aws_elastic_beanstalk_environment" "environment" {
  name          = var.name
  application   = aws_elastic_beanstalk_application.application.id
  version_label = aws_elastic_beanstalk_application_version.version.id


  # Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
  solution_stack_name = var.runtime_version

  # Required
  cname_prefix = var.name

  # Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = var.LoadBalanced ? "LoadBalanced" : "SingleInstance"
  }

  # VPC
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.create_vpc ? aws_vpc.vpc[0].id : var.custom_vpc_info.VPCId
  }
  # Subnets
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = var.create_vpc ? aws_subnet.subnet_a[0].id : var.custom_vpc_info.EBSubnets
  }
  # Ip Assoscaition
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "True"
  }
  # Instance Profile
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.create_permissions.enable ? aws_iam_instance_profile.instance_profile.id : var.create_permissions.instance_profile
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = var.create_permissions.enable ? aws_iam_role.elasticbeanstalk_service_role.id : var.create_permissions.eb_role[1]
  }
  # Health Check
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "200"
  }
  # Instance type
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }
  # Security Group
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = var.create_vpc ? aws_security_group.allow_access[0].id : var.custom_vpc_info.EBSecurityGroups
  }
  # Keypair
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = length(var.create_keypair) > 0 ? aws_key_pair.elastic_beanstalk_keypair[0].id : var.Keypair
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "gp3"
  }
  # Autoscaling - Elastic beanstalk uses autoscaling for all types. If singleInstance used, then 1min/1max.
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = var.LoadBalanced ? var.instance_size[0] : "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.LoadBalanced ? var.instance_size[1] : "1"
  }
  # Health reporting type
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # Rolling upadtes type
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable"
  }

  # Patch Level
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "patch"
  }
  #################################
  # Load Balancer Configuration
  # Load Balancer: Shared or Dedicated (shared is only supported for ALB).
  # Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-alb-shared.html
  #################################
  # Load balancer type
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerType"
      value     = "application"
    }
  }
  # Application load balancer type
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment"
      name      = "LoadBalancerIsShared"
      value     = "true"
    }
  }

  # Load Balancer ARN
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:elbv2:loadbalancer"
      name      = "SharedLoadBalancer"
      value     = aws_lb.elb[0].arn
    }
  }

  # CossZone: required if stickiness is enabled.
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:elb:loadbalancer"
      name      = "CrossZone"
      value     = "true"
    }
  }

  # Stickiness: requires SSL certificate for the ALB.
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "StickinessEnabled"
      value     = "false"
    }
  }

  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:elasticbeanstalk:environment:process:default"
      name      = "StickinessLBCookieDuration"
      value     = "86400"
    }
  }

  #####################################
  # End of Load Balancer Configuration
  #####################################
  #########################################################################################
  # SCALABILITY
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html
  #########################################################################################

  # Scaling Cooldown - 5 min at least for basic resolution.
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:asg"
      name      = "Cooldown"
      value     = "300"
    }
  }
  # BreachDuration = Period * EvaluationPeriods | It should be aligned with the Metrics Resolution Strategy used in CloudWatch.
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "Period"
      value     = "5" # min
    }
  }
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "EvaluationPeriods"
      value     = "1" # no of periods
    }
  }
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "BreachDuration"
      value     = "5"
    }
  }

  # Measure types: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html
  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "MeasureName"
      value     = "NetworkOut"
    }
  }

  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "Unit"
      value     = "Bytes"
    }
  }

  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "UpperThreshold"
      value     = "6000,000" # bytes
    }
  }

  dynamic "setting" {
    for_each = var.LoadBalanced ? [1] : []
    content {
      namespace = "aws:autoscaling:trigger"
      name      = "LowerThreshold"
      value     = "200,000" # bytes
    }
  }

  # Environment Variables - if any
  /*
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = ""
    value     = ""
  }
  ...
  */
  lifecycle {
    ignore_changes = [
      #setting,
      version_label, # Ignore changes
    ]
  }

}


/*
Sample settings:
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "Health"
  }

  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.medium"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet facing"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = "false"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "app-ec2-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "SecurityGroups"
    value = "${aws_security_group.app-prod.id}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "EC2KeyName"
    value = "${aws_key_pair.app.id}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "ServiceRole"
    value = "aws-elasticbeanstalk-service-role"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "ELBScheme"
    value = "public"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name = "CrossZone"
    value = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSize"
    value = "30"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSizeType"
    value = "Percentage"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "Availability Zones"
    value = "Any 2"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MinSize"
    value = "1"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "RollingUpdateType"
    value = "Health"
  }


*/



