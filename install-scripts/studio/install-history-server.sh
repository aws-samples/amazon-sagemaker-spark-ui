# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############
MAVEN_VERSION="3.9.9"
SPARK_VERSION="3.5.3"
SPARK_CLI_VERSION="v0.8.0"

###############
#    URLs     #
###############
GLUE_POM_URL="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/pom.xml"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
SM_SPARKK_CLI="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/sm-spark-cli.tar.gz"
SM_SPARK_CORE_UTILS="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/utils.js"
SM_SPARK_STAGE_PAGE="https://github.com/aws-samples/amazon-sagemaker-spark-ui/releases/download/${SPARK_CLI_VERSION}/stagepage.js"

# Install ca-certificates
sudo apt-get update
sudo apt-get -y install ca-certificates
printf "\nca_directory=/etc/ssl/certs" | sudo tee -a /etc/wgetrc

# Install axel
cd /tmp
sudo apt-get -y install axel gpg jq procps zip

wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list

sudo apt-get update; sudo apt-get install -y java-22-amazon-corretto-jdk

# Install Maven
sudo curl -o /opt/apache-maven-${MAVEN_VERSION}-bin.tar.gz $MAVEN_URL
cd /opt
sudo tar xzvf apache-maven-${MAVEN_VERSION}-bin.tar.gz
export PATH=/opt/apache-maven-$MAVEN_VERSION/bin:$PATH

# Download Maven Project Object Model
cd /tmp
curl -L $GLUE_POM_URL > /tmp/pom.xml

# Download Spark without Hadoop
axel -q -k --output ./spark-$SPARK_VERSION-bin-without-hadoop.tgz --num-connection 10 https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-without-hadoop.tgz

# Install Spark
sudo mkdir -p /opt/spark
sudo chown sagemaker-user /opt/spark

tar -xzf spark-$SPARK_VERSION-bin-without-hadoop.tgz && \
mv spark-$SPARK_VERSION-bin-without-hadoop/* /opt/spark && \
rm spark-$SPARK_VERSION-bin-without-hadoop.tgz

rm -f /opt/spark/jars/avro-*.jar && \
rm -f /opt/spark/jars/guava-*.jar && \
rm -f /opt/spark/jars/ivy-*.jar && \
rm -f /opt/spark/jars/mesos-*.jar && \
rm -f /opt/spark/jars/netty-codec-http2*.jar && \
rm -f /opt/spark/jars/protobuf-java-*.jar

mvn dependency:copy-dependencies -DoutputDirectory=/opt/spark/jars/

# YARN not required for Spark History Server
rm -rf /opt/spark/yarn

# Change guava dependency version
GUAVA_VERSION=$(grep -oP '<guava\.version>\K[^<]+' /tmp/pom.xml)
spark_network_common_name=$(find /opt/spark/jars/ -name "spark-network-common_*")
jar xf $spark_network_common_name
sed -i '/<parent>/,/<\/parent>/ s|<version>[0-9.]\+</version>|<version>'"$GUAVA_VERSION"'</version>|' META-INF/maven/com.google.guava/guava/pom.xml
sed -i "s/^version=.*/version=$GUAVA_VERSION/" META-INF/maven/com.google.guava/guava/pom.properties
jar uf $spark_network_common_name META-INF/maven/com.google.guava/guava/pom.xml
jar uf $spark_network_common_name META-INF/maven/com.google.guava/guava/pom.properties
rm -rf META-INF org

# Update spark-defaults.conf.template
echo "spark.driver.userClassPathFirst           true" | sudo tee -a /opt/spark/conf/spark-defaults.conf.template
echo "spark.executor.userClassPathFirst         true" | sudo tee -a /opt/spark/conf/spark-defaults.conf.template
mv /opt/spark/conf/spark-defaults.conf.template /opt/spark/conf/spark-defaults.conf

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

cd ./sm-spark-cli/studio
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
sudo rm -rf /tmp/sm-spark-cli /tmp/spark-* /tmp/pom.xml /tmp/sm-spark-cli.tar.gz