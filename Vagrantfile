Vagrant.configure("1") do |config|

  config.vbguest.auto_update = false
  config.vm.synced_folder "config/", "/vagrant",  type: "virtualbox"

  # Define k8s-master Virtual Machine
  config.vm.define "k8s-master" do |master|
    master.vm.box_download_insecure = true
    master.vm.box = "generic/centos8s"
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", ip: "#{ENV['PRIVATE_NETWORK']}.10"
    master.vm.provider "virtualbox" do |v|
      v.name = "k8s-master"
      v.memory = 4096
      v.cpus = 2
    end

    master.vm.provision "shell", path: "scripts/update.sh"
    master.vm.provision :reload
    master.vm.provision "shell", path: "scripts/common.sh"
    master.vm.provision "shell", path: "scripts/master.sh"
  end

  (1..2).each do |i|
    config.vm.define "k8s-node#{i}" do |node|
      node.vm.box_download_insecure = true
      node.vm.box = "generic/centos8s"
      node.vm.hostname = "k8s-node#{i}"
      node.vm.network "private_network", ip: "#{ENV['PRIVATE_NETWORK']}.1#{i}"
      node.vm.provider "virtualbox" do |v|
        v.name = "k8s-node#{i}"
        v.memory = 4096
        v.cpus = 2
      end
      node.vm.provision "shell", path: "scripts/update.sh"
      node.vm.provision :reload
      node.vm.provision "shell", path: "scripts/common.sh"
      node.vm.provision "shell", path: "scripts/node.sh"
    end
  end
end
