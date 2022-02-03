export FIRST_RUN=true
export PRIVATE_NETWORK=192.168.56
vagrant plugin install vagrant-vbguest
vagrant up --provision-with update
export FIRST_RUN=false
vagrant up --provision-with setup
vagrant up --provision-with deploy
