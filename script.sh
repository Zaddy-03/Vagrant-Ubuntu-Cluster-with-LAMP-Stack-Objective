#!/bin/bash

# Ensure Vagrant and VirtualBox are installed
if ! command -v vagrant > /dev/null || ! command -v vboxmanage > /dev/null; then
  echo "Vagrant and VirtualBox are not installed. Installing..."
  # You can add installation commands here for your specific OS.
  # For Ubuntu, you can use the following commands:
  # sudo apt-get update
  # sudo apt-get install -y vagrant virtualbox
fi

# Create Vagrantfile if not already present
if [ ! -f "Vagrantfile" ]; then
  echo "Creating Vagrantfile..."
  # You can copy and paste your Vagrantfile content here.
  # Make sure the content is enclosed within EOF markers as shown below.
  cat > Vagrantfile <<-EOF
  # -*- mode: ruby -*-
  # vi: set ft=ruby :

  Vagrant.configure("2") do |config|
    # Define the Ubuntu 22.04 box for master
    config.vm.define "master" do |master|
      # ... (your master configuration)
      master.vm.box = "bento/ubuntu-22.04"
      master.vm.hostname = "master"
      master.vm.network "private_network", type: "static", ip: "102.89.23.111"
      master.vm.provider "virtualbox" do |vb|
        vb.memory = 1024 # 1GB RAM
        vb.cpus = 1
      end

      # Provisioning script for the master node
      master.vm.provision "shell", inline: <<-SHELL
        # Create the 'altschool' user
        sudo useradd -m -G sudo -s /bin/bash altschool

        # set a default password for user
        echo "altschool:70669" | sudo chpasswd

        # Grant 'altschool' user root privileges
        echo "altschool ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

        # Generate an SSH key pair for 'altschool' user (without a passphrase)
        sudo -u altschool ssh-keygen -t ed25519 -N "" -f /home/altschool/.ssh/id_ed25519

        # Copy the (1-adjustment) public key to the slave node authorized key file
        sudo -u altschool ssh-copy-id -i /home/altschool/.ssh/id_ed25519.pub altschool@102.89.23.112

        # Create (2-adjustment) the /mnt/altschool/master directory
        sudo mkdir -p /mnt/altschool/master

        # Add some (3-adjustment) content to the /mnt/altschool/master directory
        echo "This is a sample file from master" | sudo tee /mnt/altschool/master/master_data.txt

        # Copy content (4-adjustment) from the /mnt/altschool/master directory to the slave /mnt/altschool/slave directory
        sudo -u altschool rsync -avz -e "ssh -o StrictHostKeyChecking=no" /mnt/altschool/master/ altschool@102.89.23.112:/mnt/altschool/slave/

        # Install Apache, MySQL, PHP, and other required packages
        sudo apt-get update
        sudo apt-get -y upgrade
        sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 mysql-server php libapache2-mod-php php-mysql

        # Start and enable Apache on boot
        sudo systemctl start apache2 || true
        sudo systemctl enable apache2 || true

        # Secure MySQL installation and initialize it with a default user and password
        echo "mysql-server mysql-server/root_password password 70669" | sudo debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password 70669" | sudo debconf-set-selections
        sudo apt-get -y install mysql-server

        # Create a sample PHP file for validation
        echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

        # Display an overview of the Linux process management, showcasing currently running processes on startup
        sudo ps aux
      SHELL
    end

    # Define the Ubuntu 22.04 box for the slave node
    config.vm.define "slave" do |slave|
      # ... (your slave configuration)
      slave.vm.box = "bento/ubuntu-22.04"
      slave.vm.hostname = "slave"
      slave.vm.network "private_network", type: "static", ip: "102.89.23.112"
      slave.vm.provider "virtualbox" do |vb|
        vb.memory = 1024 # 1GB RAM
        vb.cpus = 1
      end

      # Provisioning script for the slave node
      slave.vm.provision "shell", inline: <<-SHELL
        # Create the 'altschool' user
        sudo useradd -m -G sudo -s /bin/bash altschool

        # set a default password for user
        echo "altschool:70669" | sudo chpasswd

        # Grant 'altschool' user root privileges
        echo "altschool ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

        # Generate an SSH key pair for 'altschool' user (without a passphrase)
        sudo -u altschool ssh-keygen -t ed25519 -N "" -f /home/altschool/.ssh/id_ed25519

        # Allow SSH key-based authentication for 'altschool' user
        sudo mkdir -p /home/altschool/.ssh
        sudo cat /home/altschool/.ssh/id_ed25519.pub >> /home/altschool/.ssh/authorized_keys
        sudo chmod 700 /home/altschool/.ssh
        sudo chmod 600 /home/altschool/.ssh/authorized_keys

        # Change the (5-adjustment) ownership of the .ssh directory for the 'altschool' user
        sudo chown -R altschool:altschool /home/altschool/.ssh
        

        # Create the /mnt/altschool/slave directory
        sudo mkdir -p /mnt/altschool/slave

        # Transfer data from the Master node to the Slave node
        #sudo -u altschool scp -o StrictHostKeyChecking=no /mnt/altschool/master_data.txt altschool@102.89.23.112:/mnt/altschool/slave/

        # Install Apache, MySQL, PHP, and other required packages
        sudo apt-get update
        sudo apt-get -y upgrade
        sudo DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 mysql-server php libapache2-mod-php php-mysql

        # Start and enable Apache on boot
        sudo systemctl start apache2
        sudo systemctl enable apache2

        # Secure MySQL installation and initialize it with a default user and password
        echo "mysql-server mysql-server/root_password password 70669" | sudo debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password 70669" | sudo debconf-set-selections
        sudo apt-get -y install mysql-server

        # Create a sample PHP file for validation
        echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php
      SHELL
    end

    # Define the Ubuntu 20.04 box for the load balancer (Nginx)
    config.vm.define "loadbalancer" do |lb|
      # ... (your load balancer configuration)
      lb.vm.box = "bento/ubuntu-22.04"
      lb.vm.network "private_network", type: "static", ip: "102.89.23.113"
      lb.vm.provider "virtualbox" do |vb|
        vb.memory = 1024 # 1GB RAM
        vb.cpus = 1
      end

      # Provisioning script for the load balancer node
      lb.vm.provision "shell", inline: <<-SHELL
        # Update package lists for upgrades and new package installations
        sudo apt-get update

        # Install Nginx
        sudo apt-get install -y nginx

        # Remove the default Nginx configuration file
        sudo rm /etc/nginx/sites-enabled/default

        # Create a new Nginx configuration file using the weighted load balancing method. 
        sudo cat > /etc/nginx/sites-enabled/load_balancer <<EOF
        upstream backend {
          server 192.168.56.1 weight=3;
          server 172.20.10.5 weight=1;
        }

        server {
          listen 80;

          location / {
            proxy_pass http://backend;
          }
        }
      EOF

        # Create a symbolic link to the Nginx configuration file in the sites-available directory
        sudo ln -s /etc/nginx/sites-available/load_balancer /etc/nginx/sites-enabled/load_balancer

        # Create a landing page for the load balancer
        sudo cat > /var/www/html/index.html <<EOF
        <html>
          <head>
            <title>Load Balancer</title>
          </head>
          <body>
            <h1>Load Balancer</h1>
            <p>Load Balancer is working!</p>
          </body>
        </html>
        EOF

        # Reload Nginx to apply the changes
        sudo systemctl reload nginx || true

        # Restart Nginx to apply the changes
        sudo systemctl restart nginx || true
      SHELL
    end
  end
EOF
fi

# Start Vagrant environment
echo "Starting Vagrant environment..."
vagrant up

# Display a message indicating success
echo "Vagrant environment is up and running."
echo "You can now access the load balancer at http://102.89.23.113"
