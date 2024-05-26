#!/bin/bash
set -xe

# Export Environments into temporary file:
echo "Calling Parameters..."
while read -r name value; do export_string="${name##*/}=$value"; echo "$export_string" >> /opt/elasticbeanstalk/deployment/env; done < <(aws ssm get-parameters-by-path --path "{PARAMETERS_PATH}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)

export $(cat /opt/elasticbeanstalk/deployment/env | xargs)

