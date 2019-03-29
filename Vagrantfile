# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  config.vm.box = "ajxb/mint-19.0"
  config.vm.box_version = "1.0.2"
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder ".", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
     vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
     vb.memory = "8024"
   end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
   config.vm.provision "shell", inline: <<-SHELL
     rm /etc/apt/sources.list.d/additional-repositories.list
     touch /etc/apt/sources.list.d/additional-repositories.list
     add-apt-repository ppa:webupd8team/atom
     apt-get update
     add-apt-repository ppa:webupd8team/atom -y
     apt-get update
     apt-get install atom -y
     
     apt-get install -y git
     apt-get install -y vim
     apt-get install -y curl
     apt-get install -y ssh 
     apt-get install -y terminix
     apt-get install -y zsh
     apt-get install -y powerline fonts-powerline
     apt-get install -y zsh-theme-powerlevel9k 
     echo "source /usr/share/powerlevel9k/powerlevel9k.zsh-theme" >> ~/.zshrc
     apt-get install -y zsh-syntax-highlighting
     echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc


 #leiningen
     wget --quiet https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
     cp lein /usr/local/bin/
     chmod a+x /usr/local/bin/lein
    
     #java8
	add-apt-repository -y ppa:webupd8team/java
	apt update
	#java8 ensure non-interactive
	echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
	echo debconf shared/accepted-oracle-license-v1-1 seen true |  debconf-set-selections	
	apt install -y oracle-java8-installer

   #docker stuff 
    apt-get -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo "$UBUNTU_CODENAME") stable"
    agt-get update
    apt-get -y  install docker-ce docker-compose
    usermod -aG docker $USER

   SHELL
end
