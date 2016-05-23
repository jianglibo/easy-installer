# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|

  #config.vm.provider "hyperv"

  config.vm.provider "virtualbox" do |v|
    v.memory = 512
  end

  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "geerlingguy/centos7"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.

  #	config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.



  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.

#  config.vm.provision "shell", inline: <<-SHELL
#	yum install -y tcl tcllib dos2unix cpan expect
#  SHELL

  config.vm.define "desktop" do |desktop|
    desktop.vm.provider "virtualbox" do |v|
      v.gui = true
      v.memory = 8192
      v.customize ['createmedium', '--filename',  'f:/vms/desktop', '--size', 100000]
    end

    desktop.vm.network "private_network", ip: "192.168.33.49"
    desktop.vm.provision "shell", inline: <<-SHELL
      #yum group list
      #yum groupinstall -y "Development Tools"
      #yum -y groups install "GNOME Desktop"
      #yum install -y git
      #yum install -y gunzip
      #ln -sf /lib/systemd/system/runlevel5.target /etc/systemd/system/default.target
      # export PATH=$PATH:/opt/scripts
      # gzip -d eclipse-xx
      # tar -xf eclipse-xx
      #yum install dkms
      # rcvboxadd setup
    SHELL
  end

  config.vm.define "config-server" do |configServer|
	  configServer.vm.network "private_network", ip: "192.168.33.50"
  end

  config.vm.define "eureka-server1" do |eurekaServer1|
	  eurekaServer1.vm.network "private_network", ip: "192.168.33.51"
  end

  config.vm.define "eureka-server2" do |eurekaServer2|
	  eurekaServer2.vm.network "private_network", ip: "192.168.33.52"
  end

  config.vm.define "mongodb" do |mongodb|
	  mongodb.vm.network "private_network", ip: "192.168.33.53"
  end



  # can not disable this interface.because vagrant use it.
  #config.vm.provision "shell", inline: <<-SHELL
  #nmcli dev disconnect enp0s3
  #SHELL

end
