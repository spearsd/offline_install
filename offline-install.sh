#!/bin/bash
STILL_DEPENDENCIES=true
PACKAGE=$1
WORKING_DIR=$(pwd)/$PACKAGE
if [ -z $PACKAGE ]; then
    echo "No package passed." 2>&1
   exit 1
fi
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root user." 2>&1
   exit 1
fi
mkdir $WORKING_DIR
if [[ ! -d $WORKING_DIR ]]; then
    echo "Cannot create $WORKING_DIR. Quiting!"
    exit 1
fi
dl_dependencies() {
    STILL_DEPENDENCIES=false
    echo "Checking for additional dependency rpms required..."
    ls $WORKING_DIR | while read line; do
        echo "Testing $line..."
        rpm -Uvh --test $WORKING_DIR/$line &> offline_install_output
        if [[ ! -z "$(cat offline_install_output | grep 'is needed by' | cut -d ' ' -f 1 | cut -d '(' -f 1 | sort -u | sed -e 's/^[[:space:]]*//')" ]]; then
            STILL_DEPENDENCIES=true
            cat offline_install_output | grep 'is needed by' | cut -d ' ' -f 1 | cut -d '(' -f 1 | sort -u | sed -e 's/^[[:space:]]*//' | while read line2; do
                echo "Downloading dependency $line2..."
                yum install --downloadonly --downloaddir=$WORKING_DIR $line2 &> offline_install_output.log
            done
        fi
    done
    return 0
}
echo "Installing yum-plugin-downloadonly..."
yum install -y yum-plugin-downloadonly &> offline_install_output.log
yum install --downloadonly --downloaddir=$WORKING_DIR $PACKAGE &> offline_install_output.log
while $STILL_DEPENDENCIES; do 
    dl_dependencies
done
rm -f offline_install_output
rm -f offline_install_output.log
rm -f yum_save*
ls $PACKAGE | grep 'i686' | while read line; do
    echo "Removing $line! (not needed)"
    rm -f /tmp/$PACKAGE/$line
done
tar -czvf $PACKAGE.tar.gz $PACKAGE &> offline_install_output.log
rm -f offline_install_output.log
rm -r -f $PACKAGE
echo "$PACKAGE.tar.gz has been created."
