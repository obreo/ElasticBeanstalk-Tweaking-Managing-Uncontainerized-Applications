#  Tweaking & Managing Elastic Beanstalk - Uncontainerized Applications - SingleInstance / LoadBalanced - Deployed with CICD, Built with IaC - Terrafrom

## Decription
Elastic Beanstalk is one of the popular PaaS AWS services which deliver an easy dashboard to setup an infrastructure for a variety of software [runtimes](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html).

This article explains how to tweak and configure uncontainerized applications like NodeJS in PaaS services like AWS Elastic Beanstalk, by deploying single instance type (not load balanced) and highly available autoscalable instance type (load balanced) that supports rolling back, and integrated it with continues integration and continues delivery (CI/CD) using infrastracture as code (IaC) with Terraform.

This infrastructure implements a secure and best practice solutions to build and deploy NodeJS - and its variants - application that uses AWS SSM Parameter store for secrets.

## Architecture
![Architecture](/architecture.png)

## Brief Intro
Elastic Beanstalk is one of the Platfrom as a service - PaaS - that AWS cloud offers. It mainly uses other aws services in the backend such as CloudFormation for deployments, Amazon Linux AMI with CodeDeploy, SSM, and CloudWatch buildin agents - to deliver the logs, allow patch updates for the environment and allow Continues delivery strategy - as well as EC2 for instances, S3 for data versioning storage, RDS for database, Autoscaling Group - even for a single instance - and Load Balancer for high availability and autoscalability.

It supports deploying database instances using AWS RDS as a part of its platform, and supports different deployment strategies including All-at-once, rolling release, immutable, and blue green deployment.

Elastic Beanstalk allows running applications based on multiple runtimes, but I have divided them to two types as each can be deployed and debugged in a different way - containerized; which runs the Docker runtime, and uncontainerized; which uses non-Docker runtime as the example of the following deployment - NodeJS runtime.

### Types of deployment strategies
Each deployment strategy has its pros and cons, for testing and quick deployment for example:

1. All-at-once; which directly replaces the old deployment with the new one by replacing the application files inside the same instance, this creates little downtime. The advantages of this is quick deployment process, the disadvantage is it doesn't have rolling back in case of failure, which can only be updated manually.
2. Rolling deployment; This is used for loadbalanced type with multiple instances running at the time, it'll deploy the new update inside the same instances but in batches, this will create no downtime, but doesn't support rolling back either, the updated instances will require terminating if the deployment didn't meet the health checks.
3. Rolling deployment with additional batches; it acts as same as the rolling deployment, but it creates a complete new instances in batches instead of updating the same onces, it also doesn't support a rollback and requires updating the environment with a healthy update to recover from the failure.
4. Immutable, this creates a complete seperate autoscaling group with new instances, once health checks are passed, they will be attached to the original autoscaling group and the old instances will be discarded. This also works with the single instance type, and support rolling back in case of failure. The disadvantage is long process of deployment, as it takes about ten to fifteen minutes for each update. This can be reduced if 
5. Blue/Green, this keeps two replicas of environments running, when one environment is updated (green), the traffic will be shifted to it from the old one (blue) using what's called swapping. This type of deployment is safe and highly available. The disadvantage is the high cost as the user would pay twice the price for two environments.

Rolling deployments, and rolling deployments with batches are comparatively faster than immutable but don't support rolling back in case of failure, for this, immutable seems the most suitable, safe and highly available strategy while keeping the cost down, comparing to the rest of deployment strategies. 

Docs: [AWS Docs](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/using-features.deploy-existing-version.html)

### Deployment Configuration
To configure how an application should be installed, and decide what steps should be done pre-installation and post-installation inside the EC2 instance, Elastic beanstalk provides a number of features:
#### .ebextensions - Elastic Beanstalk Extensions
A hidden folder created in the source code which is used to control the installation and configuration of application's environment, such as running a set of scripts, environment variables, installing libraries, and do tweak the environment configuration before and after deploying the application. The commands are defined in *.config* execution files that can refer to other bash script files in the same folder.
#### .platfrom - Platfrom Hooks
Similar to .ebextensions, a hidden folder named *platfrom* which is created in the source code. Platfrom hooks have a similar purpose of ebextensions but use mainly to configure the elastic beanstalk environment - the instance running the depployment - rather than the deployment itself. It is used to run bash scripts before or after the build - compiling/extracting the applciation - and before or after the deployment - setting up/ running the application. 

Platform Hooks are also used to configure the deployment lifecycle - such as tracing, logs aggregation, environments properties setup inside the instance. 
#### Procfile and Buildfile
These are two files that are placed in the source code, both of these files are used to manage *compiling/building* the applciation - in case of Buildfile - and starting/running the application on runtime - in case of Profile. Each of these files can be defined by adding them in the application directory on the instance and set the commands using key:value method.

Deciding whether and when to use these features depends on realising the required phase to run your script within the order of running the extenions:

![Order of running extensions](https://docs.aws.amazon.com/images/elasticbeanstalk/latest/dg/images/platforms-linux-extend-order.png)

For more details:
[AWS Doc](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/platforms-linux-extend.html)

### Infrastructure Implemented Steps
1. Create a VPC with four subnets -  two for the EC2 instances and two for RDS backend in case it's used - Internet gateway, and route table to route the subnet networks to the Internet.
2. In case RDS to be used for external sources, attach it to the public route table - which routes to the internet gateway - and use ACLs to restrict access to the RDS resource.
3. For Single-Instance type of Elastic beanstalk, a load balancer won't be used, using singleinstance type, and with immutable deplyment strategy.
4. Create an Appliation load balancer, with a listener to port 80 targeting to target group forwards to port 80 instances. If HTTPS is required, then an SSL certificate can be released from ACM and use HTTPS as a listener that will forward the traffic to the target group.
5. Create Elastic beanstalk for Production, using loadbalanced type, with immutable strategy, with min 1, and max 4 instance autoscaling, then connect it to the load balacner created earlier.
6. For caching and SSL certificate, along with DDos protection, we may use CloudFront and connect it to the Load Balancer's origin, supported with AWS Shield Standard. However, to enable stikciness, an SSL certificate is required to be installed for the application load balancer, otherwise an *AWSALBCORS* error will show up.
7. For CloudFront settings, change the `domain_name` to the `CNAME_prefix` of the used elastic beanstalk environment - by default the loadbalanced type is set - make sure the protocol used aligns with the one the load balacner is using, and make sure that the 'Origin request policy' uses AllViewer policy, setting CORS policy could be needed as well.
8. Create RDS seperately, then connect it the application using environment variables, this could be safer and can be used for multi-purposes.
9. Create S3 bucket that is used to store the application's source code that will be deployed by CI, it should allow multipart-upload and allow elasticbeanstalk, codebuild, codedeploy, cloudformation, and codepipeline resources to use it.
10. Create CodeBuild application with the required policies, that uses a buildspec.yml file. then use codepipeline to use the codebuild appliation while processing.
11. Once everything is configured, save the elastic beanstalk configuration for future use.

### IaC - Terraform

1. Create VPC, Securtiy groups, and subnet, IG and route tables.
2. Create RDS.
3. Create Service role to attach it with elastic beanstalk that includes the following policies:

   1. AWSElasticBeanstalkEnhancedHealth
   2. AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy
   3. AmazonS3FullAccess - to allow S3 lifecycle policy configuration
   4. custom policy that allows:
      1. "ec2:DescribeNetworkAcls", "ec2:DescribeRouteTables"
      2. AllowingaccesstoECRrepositories
      3. AllowingAccessToELBResources
      4. AllowAccessToCustomS3bucketCreatedEarlier
      5. AllowSSM - to allow patch updates

4. Create EC2 Instance profile that will have a role to do the following:

   1. AWSElasticBeanstalkWebTier
   2. AWSElasticBeanstalkMulticontainerDocker
   3. AWSElasticBeanstalkWorkerTier
   4. AWSEC2RoleForCodeDeploy
   5. custom policy that allows:
      1. "ec2:DescribeNetworkAcls", "ec2:DescribeRouteTables"
      2. AllowSSM - for parameters retrieval.

5. Points 3.4.1 and 4.5.1 are required to avoid authorization errors while deployment from CICD.

6. Create terraform elastic beanstalk resource that includes the following:

   1. Elastic bean stalk application with s3 lifecycle policy.
   2. Elastic beanstalk application version: it will be linked with the elastic beanstalk applcation resource, and will assign the initial version name which will use a nodejs sample that will be stored in the s3 bucket.
   3. Elastic beanstalk enviroenmnt: here we will assign all the requirements of our elastic beanstalk application - using the keys and settings blocks.

7. For codepipeline, create it manually as it requires OAuth authentication which is not supported by terraform API. We may create codeBuild applciation and then connect it manually with codepipeline.

### CICD
Elastic beanstalk can be integrated with CI/CD using CI tools to build and deploy the application, or using CD only tools to deploy directly to the infrastructure and executing additional steps inside the environment - like building and starting the app, or cleaning the previous builds before deploying the new one - if needed.

#### Using CI: CodeBuild, Jenkins, Github actions, BitBucket pipelines or other third party CI tools:

In this situation we use the pipeline stages to clone the source code, build/compile it, and compress it. Then push the application to an s3 bucket that'll be used by Elastic beanstalk as a new version update. In case of NodeJS app:

1. Clone the repository (checkscm)
2. Do pre-build stage: 
   1. Installing libraries - assuming the application requires compiling before deployment else, we'll compress it as ZIP and push the file directly to the S3 bucket, which we'll refer to it using aws cli to update the elastic beanstalk environment.
   2. In case the application requires environment variables to be inserted while compiling, then we can add an addtional step to retreive them from SSM parameters store or other resources.

3. For the Build-Stage:
   1. Build Packages; npm run build.
   2. Compress files; zip it (make sure it includes all application's root files).
   3. Push to s3 bucket - make sure the path directory is available in the S3 bucket, and the bucket policy configured with ACLs disabled and has a bucket policy that allows PutObject and MultiPart policies for CodeBuild.

4. Post-Building:

   1. Create a new elastic beanstalk application vesion and update the environment using AWS CLI or - use EBCLI - using the user credentials in case of third party CI tools or role (in case of using codebuild).

*NOTE: When using codebuild, it is better to avoid using the post-building stage, because that will run everytime the build runs even if the build stage fails.*

*NOTE: ebextensions - in some cases - and procfile are required, to allow npm start in the elastic beanstalk environment. Also .npmrc file is required to allow installing packages without authentication.*

*NOTE: The user signed to the AWS CLI must have the authentication to use S3, and Elastic Beanstalk, while the S3 bucket's policy and Elastic beanstalk should have the roles required to allow each other use their resources.*

##### Using CodeBuild
Give IAM role policy to CodeBuild with the following:
    1. AdministratorAccess-AWSElasticBeanstalk policy,
    2. custom policy that allows:
       1.  S3 access to bucket - it must include MultipartUpload related policies to avoid MultupartUpload authentication error.
       2.  SSM parameter store - in case of available secrets and variables.
    3. codebuild's generic policy. - created by codebuild, which includes:
       1. VPC related policies.
       2. logs and reports generation policies.
       3. s3 access for codepipeline policies.

#### Alternative method: Using AWS Codepipeline with CodeDeploy:
Use codepipeline with codedeploy to deploy directly to elastic beanstalk and compile the application if needed using ebextensions.

   * Note: Using codedeploy directly without codepipeline is used for ecs, ec2, and autoscaling groups, not elastic beanstalk. It requires:

   1. Permission for CodeDeploy to access EC2
   2. Permission for CodeDeploy to access S3
   3. CodeDeploy agent in EC2 instance.
   4. [appspec.yml](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file.html) file to configure what and where to deploy the application in the EC2 instance.
      * It is not effecient to use the codeDeploy directly with ec2 in case of elastic beanstalk. This may also create unstable environment if the instance gets scaled or replased.
      * We may use CodeDeploy Elastic beanstalk feature in the deploy stage in codepipeline, but this works with static site applications.

1. Choose the source, for deployment, choose codedeploy with elastic beanstalk.
2. If the web app is already compiled then it shall work out of the box - if not, then use .ebextensions to build then start the application.
   1. Create .ebextensions folder in the root directory, create `FILE.config` file inside it and use either '*commands*' or '*container_commands*' as a build option based on the requirements - Check Deployment configuration section. 
   2. For the NodeJS app, use '*contaienr_commands*' run `npm inistall & npm run build`.

*NOTE: Building inside EC2 instances will consume the RAM resource, if small instances are used like t2/3.micro then the `npm run build` task will be killed and the depoyment will fail. A workaround is to create a swap area to run before the building step occures, this is also can be done using the .ebextensions by refering to a swap bash script in the app directory.
3. Keep the Procfile in the repository with `web: npm start`*

#### CodePipeline

1. Create a pipeline, choose the repository, for the building stage, choose the codebuild applciation created earlier.
2. If created with codeDeploy with elastic beanstalk, then skip the building stage and choose codedeploy with elastic beanstalk.

### Envrionment variables & SSM Parameter store
Some frameworks require environment variables to be present while compiling, like NextJs, for this, we may store the environment variables in the codebuild environments option can export them one by one, but this is a hectic step and ineffecient. For this, we may use a better and more secured way, and that is retrieving the the environment variables from an external source like SSM parameter store, then export it in the shell before building.

For persistent environment variables that require to be present on runtime as well, we can store the retrieved environment variables with the base-directory. However, this is not a safe method considering the application will be stored in an s3 bucket with the .env files.

Another way is to add the envrionment variables in the environment properties section in the elastic beansetalk configuration. However, a better solution is do this similar step inside the ec2 instance before the runtime, using .ebextensions. This step can be automated by creating an .env file in the application's base-directory or anywhere in the intance as long they can be exported before the runtime.

To store them in the applciation's directory, we can use the `container_commands` option with ebextensions.
To store them anywhere else, we can use `commands` option with ebextensions, or using `predeploy` and `prebuild` as platfrom hooks.

#### Requirements:
1. A custom policy allows `GetParameter`, `GetParametersByPath`, for the stored envrionment variables in SSM parameter store as a path.
2. This policy will be attached to CodeBuild and Elastic Beanstalk roles.
3. In the Codebuild Buildspec.yml, we'll use a bash script that will call the parameters for export:
   ```
   while read -r name value; do export_string="${name##*/}=$value"; export "$export_string"; done < <(aws ssm get-parameters-by-path --path "${parameter_path}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
   ```
   Where:

      **while; do; done**: This is a while loop which will run the following code:
         
      **read**: This reads the user input per line, created two variables; name and value, which are defined based on whitespaces of the output. This will store the environment varaibles as inputs to get exported in the shell.
      
      **export**: This will export the variable *export_string*, which stored `"${name##*/}=$value"`, the `##*/` removes the context upto the slash from the left of the value.
      
      **< <(...)**: `<` is an input redirection from a *file*, where `<(...)` is an execution block called process redirection which treats the output of command inside the brackets as a file that's values will be redirected to the *export* command line by line.
      
      **aws ssm**: using AWS CLI, ssm parameters were called by path with filtering name and value.

4. In ebextensions, using container_commands, or using the predeploy step, we'll insert these parameters in .env file in the root directory:
   
   ```
   # Saving env's in env-custom
   while read -r name value; do export_string="${name##*/}=$value"; echo "$export_string" >> FILE_PATH; done < <(aws ssm get-parameters-by-path --path "{PARAMETERS_PATH}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)

   # exporting env's
   while read name value; do export "$name$value"; done < FILE_PATH
   ```
   This will append the envrionment variables in a FILE, then export it in the shell using the FILE as a source.

*Note: We may use the same file directory where elatic beanstalk configures its envrionment properties `/opt/elasticbeanstalk/deploy/env`, however, this file gets created and deployed after the runtime, means it can only be modified in the *postdeploy* stage from the elastic beanstalk deployment order, which is useless if we need to run the envrionment variables before the runtime so they are picked when the application is running.*

*So a workaround is to do this step with a custom file to store and export the environment variables.*

### DNS setup
#### Shared load balacner
In shared load balacners, Elastic Beanstalk uses alias records to route the Application's DNS to the application load balancer, then the load balacner routes the request to the target group. 

The Application load balancer identifies the target group by setting rules - the path based rule, and the hostname rule. 

So a custom domain name should be routed to the elastic beanstalk's application DNS, not the load balancer's endpoint.

[Doc: AWS Shared Load Balancer](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-alb-shared.html) | 
[Doc: Host based routing](https://digitalcloud.training/load-balanced-architecture-with-advanced-request-routing/#:~:text=Host%2Dbased%20routing%20allows%20you,to%20as%20URL%2Dbased%20routing)

#### Dedicated load balacner
In dedicated load balancers, the load balancer is used only for a single environment, so routing a custom domain name to either of the Elastic beanstalk application's DNS or the dedicated application load balancer's endpoint isn't a problem (unless the elastic beanstalk environment is modified to a singleisntance or shared load balancer type)

#### Using Third-Party DNS Registrars
For DNS records, If an external DNS registrar is used, then ACM certificate is required, it should be added as a record in the DNS configuration of the domain, then it shall be used by cloudfront, in addition to adding the domain name Aliases in cloudfront.

Once approved, routing the domain to the cloudfront will be possible using CNAME records for the subdomain and Forward record for the host-domain that directs to the root domains.

#### Using Route53
For Route53, an alias can be created to route the custom DNS to the cloudfront endpoint that uses the elastic beanstalk environment.

## SSL Encryption

There are three methods to apply a certificate to an Elastic Beanstalk environment:
1. Using a ACM certificate with Load Balancer.
2. Using CloudFront as a proxy server with SSL certificate.
3. Using SSL on the instance level.

The third method can be implemented using a combination of `.ebextensions` and `.platform hooks` to install Certbot and automate its job on every instance deployed. 

The implementation of this method's logic is differs for each Deployment strategy, mainly between the Immutable strategy, and In-Place strategy. This is due to the event timing for each deployment, as Certbot needs to be executed once it is routed to the Elastic beanstalk endpoint, and when Nginx is ready to listen to traffic. 

Where the first is ready for the instances deployed using the In-Place strategy, and the later would be ready after the health checks are met. So we can assume the best stage to run certbot is in the `Postdeploy` using platfrom hooks. 

However, for the Immutable deployment strategy, the instance being deployed is being prepared in a temporarily created autoscaling group, while the Elastic beanstalk endpoint is still connected to the old instance, and this occurs even during the Postdeploy method. Hence certbot will fail highlighting challenges failure.

To solve this, we can schuedle the certbot job to run minutes after the postdeploy method is initiated, which gives the instance time to get attached to the original autoscaling group and get DNS routed to the new instance instead of the old once.

## In-Place

Create `.ebextensions` folder that will run a `script.conf` file, which will have a `container_command` that installs certbot. Create `.platform/hooks/postdeploy/script.sh` which will contain the certbot's command to get the certificate to the Elastic beanstalk's endpoint.

## Immutable

Similar to the In-Place method, but change `.platform/hooks/postdeploy/script.sh` code to schedule certbot execution about 10 minutes later. This can be done using `at` linux command.

## Using Multi-Stage Environments

If multi staged environments is used, e.g. dev - staging - prod, we can enhance the logic little further:
1. Create `.platform/hooks/postdeploy/scripts/script.sh` and `.platform/hooks/postdeploy/script_runner.sh`
2. The `script_runner.sh` will schedule running the `/scripts/script.sh` file, which will contain the certbot job.
3. The certbot script will grab the instance metadata, particularly *elastic beanstalk envrionment id* and environment DNS endpoint.
4. Using conditional if-statements, compare the output to the elastic beanstalk endpoints development and production endpoints, and the certbot will generate a new certificate for the right instance with the related DNS.

### Notes & Troubleshooting
1. The application's port can be modified using a predefined AWS environment variable `PORT`.
2. For t2/3.micro instance, running npm run build causes memory full, so create a swap script and run it by .ebextensions
3. If npm requires permission while building, use .npmrc file with `unsafe-perm=true`.
4. Always trace the problems using the logs in /var/log directory.
5. For Immutable deployment logs, check elastic beanstalk's bucket's logs, they persist for one hour after each event.
6. Use ebextensions to run npm install before depoyment in elastic beanstalk to solve error `sh: not found`.
7. Save configuration when setting the elastic beanstalk environment to use it later as endpoint restore when required.
8. Enabling Stickiness in the load balancer requires an SSL certitificate particularily for the ALB, this can be created using ACM.
9. We can trace the unknown errors from the log files in /var/log directory as well as checking the **messages** log file.

# Notes for Python

To run Streamlit server over elastic beanstalk:
1. Create a **Procfile** in the root directory of the source code and make it like this:
`web: echo "<EMAIL> | "streamlit run application.py --server.port 8000`
Port 8000 is the default port that runs on elastic beanstalk for Python

2. Modify your *elastic beanstalk environment configuration* from the **AWS Dashboard** by navigating to Configuration > Configure updates, monitoring, and logging > Platfrom Software: modify **WSGIPath** to *app.py* or *application.py* - the name of your python .py file.

# Notes for Nginx
Nginx default configuration can be changed by creating a **.platfrom/nginx/** or **.platfrom/nginx/conf.d** direcotry then adding either nginx.conf file which will override the default one in /etc/nginx/nginx.conf in the instance. Or adding conf.d/FILE_NAME.conf with a set of nginx configurations which will override the default ones.

As we can also add a new reverse proxy configuration at the conf.d direcotry.

example:
to modify the hash size and client upload size, we can modify two arguments in nginx.

1. Create **FILE_NAME.conf** file in **.platform/nginx/conf.d** and add the following:
```
client_max_body_size 250M;
types_hash_max_size 1024;
```
This will override the related configuration in the elastic beanstalk environment.
