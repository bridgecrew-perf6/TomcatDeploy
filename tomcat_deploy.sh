#!/bin/bash
jdk=https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/releases/download/jdk8u265-b01/OpenJDK8U-jdk_x64_linux_8u265b01.tar.gz 
tomcat=https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.8/bin/apache-tomcat-9.0.8.tar.gz
jdk_version=openjdk-8u265-b01
tomcat_service_name=SERVICE_NAME
tomcat_instance_dir=/opt/instances-tomcat/$tomcat_service_name # will be created if not existent
tomcat_username=tomcat9


# Abort if not super user
if [[ ! $(whoami) = "root" ]]; then
    echo "You must have administrative privileges to run this script"
    exit 1
fi
################# OpenJDK Install #################

# Download JDK to /tmp/
cd /tmp/ || exit

filename="${jdk_version}.tar.gz"
wget -O $filename $jdk 
 
# Unpack the JDK
tar -zxf $filename

 
# Create a location to save the JDK, and move it there
mkdir -p /usr/local/java
mv $jdk_version /usr/local/java
JAVA_HOME=/usr/local/java/$jdk_version

# Place links to java commands in /usr/bin, and set preferred sources
update-alternatives --install /usr/bin/java java $JAVA_HOME/bin/java 100
update-alternatives --install /usr/bin/javac javac $JAVA_HOME/bin/javac 100
update-alternatives --install /usr/bin/jar jar $JAVA_HOME/bin/jar 100

# delete JDK archive
rm $filename


################# JAVA_HOME #################
JAVA_HOME=/usr/local/java/$jdk_version
export JAVA_HOME=$JAVA_HOME # set JAVA_HOME for current session
echo "export JAVA_HOME=$JAVA_HOME" > /etc/profile.d/java_home.sh #make it persistent

################# Tomcat Install #################
# get tarball filename
filename=$(basename "$tomcat")

#Download Tomcat
wget $tomcat

#untar and get foldername by stripping .tar.gz
tar -zxf $filename
folder=${filename%.tar.gz}

#create directory for tomcat and move the folder
mkdir -p /usr/local/tomcat
mv $folder /usr/local/tomcat/

################# CATALINA_HOME #################
CATALINA_HOME=/usr/local/tomcat/$folder
export CATALINA_HOME=$CATALINA_HOME # set CATALINA_HOME for current session
echo "export CATALINA_HOME=$CATALINA_HOME" > /etc/profile.d/catalina_home.sh #make it persistent

cd /usr/local/tomcat/$folder/bin/
chmod +x ./*.sh

################# CREATE USER FOR TOMCAT #################
useradd -r $tomcat_username -s /bin/false # system user w/o login 

#grant rights on tomcat folder
chown -R $tomcat_username:$tomcat_username $CATALINA_HOME


################# CREATE INSTACE FOLDER #################
mkdir -p $tomcat_instance_dir
mkdir -p $tomcat_instance_dir/logs
mkdir -p $tomcat_instance_dir/conf
#grant rights on instance dir
chown -R $tomcat_username:$tomcat_username $tomcat_instance_dir


################# TODO: COPY APP-FILES #################
# copy conf/server.xml and app files to $tomcat_instance_dir


################# CREATE SERVICE #################
cat > /etc/systemd/system/$tomcat_service_name.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target 

[Service]
Type=forking 
Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=$tomcat_instance_dir/tomcat.pid
Environment=CATALINA_HOME=$CATALINA_HOME
Environment=CATALINA_BASE=$tomcat_instance_dir
Environment='CATALINA_OPTS=-Xms1024M -Xmx6144M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=$CATALINA_HOME/bin/startup.sh
ExecStop=$CATALINA_HOME/bin/shutdown.sh 
User=$tomcat_username
Group=$tomcat_username
UMask=0007
RestartSec=10
Restart=always 

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start $tomcat_service_name
systemctl enable $tomcat_service_name
