#!/bin/bash
STILL_DEPENDENCIES=true
PACKAGE=$1

if [ -z $PACKAGE ]; then
    echo "No package passed." 2>&1
   exit 1
fi
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root user." 2>&1
   exit 1
fi
dl_dependencies() {
    STILL_DEPENDENCIES=false
    echo "Downloading dependencies for rpms located in /tmp/$PACKAGE..."
    ls /tmp/$PACKAGE | while read line; do
        echo "Testing $line..."
        rpm -Uvh --test /tmp/$PACKAGE/$line &> /tmp/offline_install_output
        if [[ ! -z "$(cat /tmp/offline_install_output | grep 'is needed by' | cut -d ' ' -f 1 | cut -d '(' -f 1 | sort -u | sed -e 's/^[[:space:]]*//')" ]]; then
            STILL_DEPENDENCIES=true
            cat /tmp/offline_install_output | grep 'is needed by' | cut -d ' ' -f 1 | cut -d '(' -f 1 | sort -u | sed -e 's/^[[:space:]]*//' | while read line2; do
                echo "Downloading dependency $line2..."
                yum install --downloadonly --downloaddir=/tmp/$PACKAGE $line2 &> /tmp/offline_install_output.log
            done
        fi
    done
    return 0
}

yum install -y yum-plugin-downloadonly &> /tmp/offline_install_output.log
mkdir /tmp/$PACKAGE
yum install --downloadonly --downloaddir=/tmp/$PACKAGE $PACKAGE &> /tmp/offline_install_output.log
while $STILL_DEPENDENCIES; do 
    dl_dependencies
done
rm -f /tmp/$PACKAGE/output
mv /tmp/offline_install_output.log /tmp/$PACKAGE/offline_install_output.log
rm -f /tmp/yum_save*
ls /tmp/$PACKAGE | grep 'i686' | while read line; do
    echo "removing $line! (not needed)"
    rm -f /tmp/$PACKAGE/$line
done
echo "Dependancies for $PACKAGE are downloaded at /tmp/$PACKAGE."