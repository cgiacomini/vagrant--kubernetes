Vagrant.configure("2") do |config|

  if ENV['FIRST_RUN'] == 'true'
     config.vbguest.auto_update = false
  else
     config.vm.synced_folder "config/", "/vagrant",  type: "virtualbox"
  end

  config.vm.define "k-master" do |master|
    master.vm.box_download_insecure = true
    master.vm.box = "centos/stream8"
    master.vm.hostname = "k-master"
    master.vm.network "private_network", ip: "#{ENV['PRIVATE_NETWORK']}.10"
    master.vm.provider "virtualbox" do |v|
      v.name = "k-master"
      v.memory = 4096
      v.cpus = 2
    end
    master.vm.provision "update", type: "shell", inline: <<-UPDATE
        yum -y update
        shutdown now
    UPDATE
    master.vm.provision "setup",  type: "shell", path: "scripts/common.sh"
    master.vm.provision "deploy", type: "shell", path: "scripts/master.sh"
  end

  (1..2).each do |i|
    config.vm.define "k-node#{i}" do |node|
      node.vm.box_download_insecure = true
      node.vm.box = "centos/stream8"
      node.vm.hostname = "k-node#{i}"
      node.vm.network "private_network", ip: "#{ENV['PRIVATE_NETWORK']}.1#{i}"
      node.vm.provider "virtualbox" do |v|
        v.name = "k-node#{i}"
        v.memory = 4096
        v.cpus = 2
      end
      node.vm.provision "update", type: "shell", inline: <<-UPDATE
        yum -y update
        shutdown now
      UPDATE
      node.vm.provision "setup",  type: "shell", path: "scripts/common.sh"
      node.vm.provision "deploy", type: "shell", path: "scripts/node.sh"
    end
  end
end
