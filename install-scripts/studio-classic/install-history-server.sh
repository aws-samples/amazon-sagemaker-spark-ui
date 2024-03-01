# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############
SPARK_VERSION="3.3.1"
SPARK_CLI_VERSION="v0.2.0"

###############
#    URLs     #
###############
EPEL_RELEASE_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
GLUE_POM_URL="https://raw.githubusercontent.com/aws-samples/aws-glue-samples/master/utilities/Spark_UI/pom.xml"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz"
SM_SPARKK_CLI="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/sm-spark-cli.tar.gz"
SM_SPARK_CORE_UTILS="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/utils.js"
SM_SPARK_STAGE_PAGE="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/stagepage.js"

# Install wget
cd /tmp
sudo yum install -y wget zip

# Control JupyterLab version
export AWS_SAGEMAKER_JUPYTERSERVER_IMAGE="${AWS_SAGEMAKER_JUPYTERSERVER_IMAGE:-'jupyter-server-3'}"

sudo yum install -y jq procps

# Install Java
if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server" ]; then
    sudo rpm --import https://yum.corretto.aws/corretto.key
    sudo curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
    sudo yum install -y java-11-amazon-corretto-devel
else
    sudo yum install -y java-11-amazon-corretto-headless
fi

# Install Maven
sudo curl -o /opt/apache-maven-3.8.6-bin.tar.gz $MAVEN_URL
cd /opt
sudo tar xzvf apache-maven-3.8.6-bin.tar.gz
export PATH=/opt/apache-maven-3.8.6/bin:$PATH

# Download Maven Project Object Model
cd /tmp
curl -O $GLUE_POM_URL

# Download Spark without Hadoop
wget -O ./spark-$SPARK_VERSION-bin-without-hadoop.tgz https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-without-hadoop.tgz

# Install Spark
sudo mkdir -p /opt/spark
sudo chown sagemaker-user /opt/spark

tar -xzf spark-$SPARK_VERSION-bin-without-hadoop.tgz && \
mv spark-$SPARK_VERSION-bin-without-hadoop/* /opt/spark && \
rm spark-$SPARK_VERSION-bin-without-hadoop.tgz

mvn dependency:copy-dependencies -DoutputDirectory=/opt/spark/jars/

rm /opt/spark/jars/jsr305-3.0.0.jar && \
rm /opt/spark/jars/jersey-*-1.19.jar && \
rm /opt/spark/jars/jackson-dataformat-cbor-2.6.7.jar && \
rm /opt/spark/jars/joda-time-2.8.1.jar && \
rm /opt/spark/jars/jmespath-java-*.jar && \
rm /opt/spark/jars/aws-java-sdk-core-*.jar && \
rm /opt/spark/jars/aws-java-sdk-kms-*.jar && \
rm /opt/spark/jars/aws-java-sdk-s3-*.jar && \
rm /opt/spark/jars/ion-java-1.0.2.jar

# Update utils.js and stagepage.js
mkdir ./tmp_utils
cd tmp_utils
mkdir -p org/apache/spark/ui/static
curl -L $SM_SPARK_CORE_UTILS > ./org/apache/spark/ui/static/utils.js
curl -L $SM_SPARK_STAGE_PAGE > ./org/apache/spark/ui/static/stagepage.js
spark_core_name=$(find /opt/spark/jars/ -name "spark-core_*")
jar uf $spark_core_name org/apache/spark/ui/static/utils.js
jar uf $spark_core_name org/apache/spark/ui/static/stagepage.js
cd ..
rm -rf ./tmp_utils

# Copy CLI scripts
sudo mkdir -p /opt/sm-spark-cli/bin

curl -L $SM_SPARKK_CLI > ./sm-spark-cli.tar.gz
sudo tar xzvf sm-spark-cli.tar.gz

cd ./sm-spark-cli/studio-classic
sudo cp -r commands /opt/sm-spark-cli/bin/
sudo cp -r sm-spark-cli /opt/sm-spark-cli/bin/

sudo chmod +x /opt/sm-spark-cli/bin/sm-spark-cli
sudo chmod +x /opt/sm-spark-cli/bin/commands/*

sudo chown sagemaker-user /opt/sm-spark-cli
sudo chown sagemaker-user /opt/sm-spark-cli/bin

# Add Auto-completion
sudo cp -r sm-spark-cli.completion /etc/bash_completion.d/ 
sudo chmod +x /etc/bash_completion.d/sm-spark-cli.completion
grep -qxF 'source /etc/bash_completion.d/sm-spark-cli.completion' ~/.bash_profile || echo 'source /etc/bash_completion.d/sm-spark-cli.completion' >> ~/.bash_profile

# Add simlink
cd /usr/bin
sudo ln -s /opt/sm-spark-cli/bin/sm-spark-cli sm-spark-cli

# Remove tmp files
sudo rm -rf /tmp/sm-spark-cli /tmp/spark-* /tmp/pom.xml