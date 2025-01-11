#!/bin/bash

# Define Certificate Auth
EMAIL=""
DEV_CUSTOM_DOMAIN=""
PROD_CUSTOM_DOMAIN=""
# Define environment endpoints
DEV_ENDPOINT=""
PROD_ENDPOINT=""

# Retrive instance metadata
INSTANCE_ID=$(TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)


REGION=$(TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

# Check if the instnance is part of elastic beanstalk environment
ENV_ID=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=elasticbeanstalk:environment-id" \
    --region $REGION \
    --query "Tags[0].Value" \
    --output text)
    
if [ -z "$ENV_ID" ]; then
    echo "Error: Not running in an Elastic Beanstalk environment" >> ~/certbot_runner/log
    exit 1
fi


# Get environment info including CNAME
ENV_INFO=$(aws elasticbeanstalk describe-environments \
    --environment-ids $ENV_ID \
    --region $REGION \
    --query "Environments[0].[EnvironmentName,CNAME]" \
    --output text)
ENV_NAME=$(echo "$ENV_INFO" | cut -f1)
DOMAIN_URL=$(echo "$ENV_INFO" | cut -f2)

# Check environment and schedule certbot accordingly
if [ "$DOMAIN_URL" = "$DEV_ENDPOINT" ]; then
    echo "Development environment detected - scheduling certbot with staging" >> ~/certbot_runner/log
    sudo certbot -v -n -d $DEV_ENDPOINT --staging --nginx --agree-tos --email $EMAIL  >> ~/certbot_runner/log 2>&1
    echo "0 0 * */2 1 sudo certbot renew --nginx >> ~/certbot_runner/log 2>&1" | crontab -
    echo "Flushing Cloudfront cache"  >> ~/certbot_runner/log
    aws cloudfront create-invalidation --distribution-id E1LW315A1684TC --paths '/*'  >> ~/certbot_runner/log 2>&1
elif [ "$DOMAIN_URL" = "$PROD_ENDPOINT" ]; then
    echo "Production environment detected - scheduling certbot" >> ~/certbot_runner/log
    sudo certbot -v -n -d $PROD_ENDPOINT -d $PROD_CUSTOM_DOMAIN -d www.$PROD_CUSTOM_DOMAIN --staging --nginx --agree-tos --email $EMAIL >> ~/certbot_runner/log 2>&1
    echo "0 0 * */2 1 sudo certbot renew --nginx >> ~/certbot_runner/log 2>&1" | crontab -
else
    echo "Environment not recognized as dev or prod" >> ~/certbot_runner/log
fi
