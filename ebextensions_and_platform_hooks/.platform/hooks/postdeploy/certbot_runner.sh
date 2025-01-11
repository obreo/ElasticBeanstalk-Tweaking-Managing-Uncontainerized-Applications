#!/usr/bin/env bash

# Create an executable bash file in directory
mkdir ~/certbot_runner
sudo cp /var/app/current/.platform/hooks/postdeploy/scripts/certbot_script.sh ~/certbot_runner/certbot_script.sh
sudo chmod +x ~/certbot_runner/certbot_script.sh

# Schedule certbot_script.sh to run after 10 min from Postdeploy stage
if ! command -v at > /dev/null 2>&1; then
    echo "Error: 'at' command is not installed. Please install it and try again." >> ~/certbot_runner/log
    exit 1
fi

echo "sudo ~/certbot_runner/certbot_script.sh" | at now + 8 minutes
echo "certbot script has been scheduled ro run 8 minutes after postdeployment initialization." >> ~/certbot_runner/log
