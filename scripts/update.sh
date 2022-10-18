###############################################################################
log()
{
   echo "********************************************************************************"
   echo [`date`] - $1
   echo "********************************************************************************"
}

###############################################################################

# If man in the midle need proxy certificate to be installed or nothing works
if [ -d '/vagrant/RootCA' ];
then
    log "Adding Self signed Root CA certificates"
    sudo cp /vagrant/RootCA/* /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust
fi

log "Update system packages"
sudo dnf update -y
