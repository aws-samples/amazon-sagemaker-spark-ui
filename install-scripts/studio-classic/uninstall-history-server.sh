# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

# Remove installed packages
sudo yum remove -y axel epel-release jq procps

# Remove Java
sudo yum remove -y java-11-amazon-corretto-headless
# Remove Maven
PATH=$(echo "$PATH" | sed -e 's/:\/opt\/apache-maven-3.8.6\/bin$//')
export PATH=$PATH

# Remove SM Spark CLI
PATH=$(echo "$PATH" | sed -e 's/:\/opt\/sm-spark-cli$//')
export PATH=$PATH

# Remove Spark
sudo rm -rf /opt/spark

# Remove Spark UI CLI
sudo rm -rf /opt/sm-spark-cli

# Remove Auto-completion
sudo rm -rf /etc/bash_completion.d/sm-spark-cli.completion
if [ -f ~/.bash_profile ]; then
    sed -i '/source \/etc\/bash_completion.d\/sm-spark-cli.completion/d' ~/.bash_profile
    rm -rf /tmp/space-metadata.json
fi

# Remove symlink
cd /usr/bin
sudo rm sm-spark-cli

# Remove tmp files
sudo rm -rf /tmp/sm-spark-cli /tmp/spark-* /tmp/pom.xml