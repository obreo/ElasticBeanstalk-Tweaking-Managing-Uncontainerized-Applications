#!/bin/bash
echo "Calling Parameters to env..."
while read -r name value; do export_string="${name##*/}=$value"; echo "$export_string" >> /opt/elasticbeanstalk/deployment/env-custom; done < <(aws ssm get-parameters-by-path --path "{PARAMETERS_PATH}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)

echo "exporting env's"
while read name value; do export "$name$value"; done < /opt/elasticbeanstalk/deployment/env-custom

source /opt/elasticbeanstalk/deployment/env-custom

echo "automating env sourcing using .bashrc file"

echo 'while read name value; do export "$name$value"; done < /opt/elasticbeanstalk/deployment/env-custom' >> ~/.bashrc

source ~/.bashrc
