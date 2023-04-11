# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############
GLUE_VERSION="3_0"
SPARK_VERSION="3.1.3"

EPEL_RELEASE_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
#SM_SPARKK_CLI='https://github.com/aws-samples/amazon-sagemaker-studio-spark-ui/releases/download/v0.0.1/sm-spark-cli.tar.gz'
SM_SPARKK_CLI="https://ee-assets-prod-us-east-1.s3.us-east-1.amazonaws.com/modules/aab8e619f53f4d79b65d2272f3ee8de1/v1/releases/sm-spark-cli.tar.gz"

# Install axel
cd /tmp
sudo yum install -y wget
wget $EPEL_RELEASE_URL
sudo yum install -y epel-release-latest-*.noarch.rpm
sudo yum install -y axel
sudo rm -rf epel-release-latest-*.noarch.rpm

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
sudo curl -o /opt/apache-maven-3.8.6-bin.tar.gz https://archive.apache.org/dist/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz
cd /opt
sudo tar xzvf apache-maven-3.8.6-bin.tar.gz
export PATH=/opt/apache-maven-3.8.6/bin:$PATH

# Download Maven Project Object Model
cd /tmp
curl -O https://raw.githubusercontent.com/aws-samples/aws-glue-samples/master/utilities/Spark_UI/glue-$GLUE_VERSION/pom.xml

# Download Spark without Hadoop
axel -q --output ./spark-$SPARK_VERSION-bin-without-hadoop.tgz --num-connection 10 https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-without-hadoop.tgz

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

# Copy CLI scripts
sudo mkdir -p /opt/sm-spark-cli/bin

curl -L $SM_SPARKK_CLI > ./sm-spark-cli.tar.gz
sudo tar xzvf sm-spark-cli.tar.gz

cd ./sm-spark-cli
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