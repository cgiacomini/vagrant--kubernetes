Vagrant.configure("2") do |config|

  config.vm.synced_folder ".", "/vagrant"
  config.vm.define "k-master" do |master|
    master.vm.box_download_insecure = true
    master.vm.box = "generic/centos8"
    master.vm.hostname = "k-master"
    master.vm.network "private_network", ip: "192.168.56.10"
    master.vm.provider "virtualbox" do |v|
      v.name = "k-master"
      v.memory = 4048
      v.cpus = 2
    end
    master.vm.provision "shell", path: "scripts/common.sh"
    master.vm.provision "shell", path: "scripts/master.sh"
  end

  (1..2).each do |i|
    config.vm.synced_folder ".", "/vagrant"
    config.vm.define "k-node#{i}" do |node|
      node.vm.box_download_insecure = true
      node.vm.box = "generic/centos8"
      node.vm.hostname = "k-node#{i}"
      node.vm.network "private_network", ip: "192.168.56.1#{i}"
      node.vm.provider "virtualbox" do |v|
        v.name = "k-node#{i}"
        v.memory = 4024
        v.cpus = 2
      end
      node.vm.provision "shell", path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/node.sh"
    end
  end
end
