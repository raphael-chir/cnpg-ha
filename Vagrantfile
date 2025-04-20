Vagrant.configure("2") do |config|

  config.vm.define "k8s" do |k8s|
    k8s.vm.box = "ubuntu/jammy64"
    k8s.vm.hostname = "k8s"
    k8s.vm.network "private_network", ip: "192.168.56.10"
    k8s.vm.provider "virtualbox" do |vb|
      vb.cpus = 6
      vb.memory = 10240
    end
    k8s.vm.provision "shell", inline: <<-SHELL
      set -e
      bash /vagrant/00-init-tools.sh
      bash /vagrant/01-init-cnpg.sh
    SHELL
  end

  # Shared folder
  config.vm.synced_folder ".", "/vagrant"
end