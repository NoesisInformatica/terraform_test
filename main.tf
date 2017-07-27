# Test example
variable "external_gateway" {
	default = "893a5b59-081a-4e3a-ac50-1e54e262c3fa"
}

variable "n3_gateway" {
	default = "893a5b59-081a-4e3a-ac50-1e54e262c3fa"
}

variable "n3_ip_pool" {
	default = "11.22.0.0/16"
}

# Configure the OpenStack Provider
provider "openstack" {
	# no need to define anything cos it gets pulled via the shell environments
}

# Define our network
resource "openstack_networking_network_v2" "network_1" {
  name           = "network_1"
  admin_state_up = "true"
}

# Create a subnet for our network
resource "openstack_networking_subnet_v2" "subnet_1" {
  name       = "subnet_1"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  cidr       = "192.168.199.0/24"
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Define a router to connect to the internet
resource "openstack_networking_router_v2" "router_1" {
  name             = "my_router"
  external_gateway = "${var.external_gateway}"
}

# Now connect the router to the network using an interface
resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = "${openstack_networking_router_v2.router_1.id}"
  subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}

# Now add ssh public key so we can access the resource --// todo move public key to a variable
resource "openstack_compute_keypair_v2" "bastion-keypair" {
  name       = "bastion-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDjb0RsR8ZtABGIRC/uzjZZClq2drvH58SiLgDQhU02+U3V1AKTAIk/SorCCYBgsFdypjhOoOODH8fzkCURzUqJIYwNEmGd9agQcT4IWiHux5voJxLH9lUstK4ZFZgglkwK0/40lUxq7jxJLcw+m1eMxfnp7mGel5eR5qi7lHY6DBIi2MkLPO3j5EgwCA6YI7xuMgYBqhOgigzZ0Yg89l9Pf6VwV+BAnUXM7Po9AKXe82k4y2faLHoBDfA8OUdqoZYiPgEE8diFt/fRc+7ZPFK9PrHX9pxTnrCW9XM0/cKG4ZM9ONvYKtoE/dL4mQEkVNNVd6K4Igo9ee6dGSW0yalixvlyn7nvp3e77x1Dkr1oXTIzASxEfJ4QUj8sUdv/aaE5q/h1rK+lih6FpkHNpFd9nVaV+byWiBPT9pEey0ukGc0hj7ET9BnZSAexIMXBI4eU+RsMwl+E8ls/xqdwIikhSNQeohSX2pNjnrxBFG9xxp9Ykh4KC2I1nJWDUZyj8Y0OvP7A63QL7hdKqlhdXsGvaDqJKiSaOJm5uNB5zDm3KYgslCuHiKoP1lJJ33xgWxAMSqIF4oLMX5vlB0l7JcYWmvr1idj9cfOh1C9P9rrtjsifr+3nhT03gtqi/zD2oR3wdn1LJOi/o5pc9KeKXEdgu3sQAii58SP3/NwMLsC4CQ=="
}

resource "openstack_compute_keypair_v2" "secret-keypair" {
  name       = "secret-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCue01B/2Yzhz2y33HD3yn2dmid8Eh81jvUcwAv5dqyQODefqrR+znv9GxYdf43+Syy/Lz8XMVv1FNKdYKQ3SL9aPT4CL/by9cCF6hjOkqrGpCIxdI7q7aZpznlItcq+XyHqRHaab7Mj4GrU1SoWCpFiogU5Oxw0AvMb4fZyA7dsKr8adr6Ply1CZEsXbseSW5a7uAdpDidQn2jW7rFyxmi2uy/6y6aNzBqcz/zco8lk6nTdja0sAH44BzJK/fzrsNMlZrgSZRfy938mez7tfUmILr4zd07aQ3wSoToRJRn1yxJSBXOklXkJMLhnTGi8xj3a9wpVuH9t6SMP8m+7XoB"
}


# Now specify an image - using centos72 from openstack
resource "openstack_compute_instance_v2" "basic" {
  name            = "bastion"
  image_id        = "c09aceb5-edad-4392-bc78-197162847dd1"
  flavor_name       = "t1.tiny"
  key_pair        = "${openstack_compute_keypair_v2.bastion-keypair.name}"
  security_groups = ["default", "${openstack_compute_secgroup_v2.secgroup_1.name}"]

  metadata {
    this = "centos 72 base"
  }

  network {
    name = "${openstack_networking_network_v2.network_1.name}"
  }

  network {
    name = "${openstack_networking_network_v2.n3_network.0.name}"
  }
}

# Now declare security group with default ports open
resource "openstack_compute_secgroup_v2" "secgroup_1" {
  name        = "my_secgroup"
  description = "my security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

# Now declare security group with http ports open - 80 and 443
resource "openstack_compute_secgroup_v2" "http_group" {
  name        = "http_group"
  description = "Http only group"

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

# Now acquire a public ip for our instance - here we specify 'internet' because that is the pool set up by UKCloud
resource "openstack_networking_floatingip_v2" "floatip_1" {
  pool = "internet"
}

# Now acquire a public ip for our instance - here we specify 'internet' because that is the pool set up by UKCloud
resource "openstack_networking_floatingip_v2" "floatip_2" {
  pool = "internet"
}

# Now associate the public ip with our instance
resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.floatip_1.address}"
  instance_id = "${openstack_compute_instance_v2.basic.id}"

  	# This should upload the ssh private key from local config folder
    provisioner "file" {
    	source = "./config/secret-key.pem"
    	destination = "/home/centos/.ssh/id_rsa"
    	connection {
    		host = "${openstack_networking_floatingip_v2.floatip_1.address}"
    		user = "centos"
    		timeout = "1m"
    	}
    }

    # set permissions on private key to 0600
    provisioner "remote-exec" {
	    inline = [
	      "chmod 0600 ~/.ssh/id_rsa"
	    ]
	    connection {
    		host = "${openstack_networking_floatingip_v2.floatip_1.address}"
    		user = "centos"
    		timeout = "1m"
    	}
  }
}

# Now associate the public ip with our APIgateway instance
resource "openstack_compute_floatingip_associate_v2" "fip_2" {
  floating_ip = "${openstack_networking_floatingip_v2.floatip_2.address}"
  instance_id = "${openstack_compute_instance_v2.w3_apigateway.id}"
}

# Now create API gateway instance

# Now specify an image - using centos72 from openstack for API gateway
resource "openstack_compute_instance_v2" "w3_apigateway" {
  name            = "w3_apigateway"
  image_id        = "c09aceb5-edad-4392-bc78-197162847dd1"
  flavor_name       = "t1.tiny"
  key_pair        = "${openstack_compute_keypair_v2.secret-keypair.name}"
  security_groups = ["default", "${openstack_compute_secgroup_v2.http_group.name}"]

  metadata {
    this = "centos 72 base"
  }

  network {
    name = "${openstack_networking_network_v2.network_1.name}"
  }
}

# Phase II  - recreate dummy N3 
# Define our network
resource "openstack_networking_network_v2" "n3_network" {
  count = "3"
  name           = "n3_network_${count.index}"
  admin_state_up = "true"
}

# Create a subnet for our network - but we need 3 sub nets and we use cidr host function to allocate 
# ip instead of adding it manually
resource "openstack_networking_subnet_v2" "n3_subnet" {
  name       = "n3_subnet_${count.index}"
  count = "3"
  network_id = "${element(openstack_networking_network_v2.n3_network.*.id, count.index)}"
  cidr       = "${cidrsubnet(var.n3_ip_pool, 8, (count.index+1)*10)}"
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Define a router to connect to the internet
resource "openstack_networking_router_v2" "n3_router" {
  name             = "n3_router"
  external_gateway = "${var.n3_gateway}"
}

# Now connect the router to the network using an interface - but we loop through the 3 subnets to connect them to the router
resource "openstack_networking_router_interface_v2" "n3_router_interface" {
  count = "3"
  router_id = "${openstack_networking_router_v2.n3_router.id}"
  subnet_id = "${element(openstack_networking_subnet_v2.n3_subnet.*.id, count.index)}"
}

# Now create N3 API gateway instance
# Now specify an image - using centos72 from openstack for API gateway
resource "openstack_compute_instance_v2" "n3_apigateway" {
  name            = "n3_apigateway"
  image_id        = "c09aceb5-edad-4392-bc78-197162847dd1"
  flavor_name       = "t1.tiny"
  key_pair        = "${openstack_compute_keypair_v2.secret-keypair.name}"
  security_groups = ["default", "${openstack_compute_secgroup_v2.http_group.name}"]

  metadata {
    this = "centos 72 base"
  }

  network {
    name = "${openstack_networking_network_v2.n3_network.0.name}"
  }

  network {
    name = "${openstack_networking_network_v2.n3_network.1.name}"
  }
}

# Get a public IP for N3 api gateway
resource "openstack_networking_floatingip_v2" "n3_floatip" {
  pool = "internet"
}

# Now associate the N3 public ip with our N3 APIgateway instance
resource "openstack_compute_floatingip_associate_v2" "n3_fip" {
  floating_ip = "${openstack_networking_floatingip_v2.n3_floatip.address}"
  instance_id = "${openstack_compute_instance_v2.n3_apigateway.id}"
}

# Now create db server - using centos72 from openstack
resource "openstack_compute_instance_v2" "db_server" {
  name            = "db_server"
  image_id        = "c09aceb5-edad-4392-bc78-197162847dd1"
  flavor_name       = "t1.tiny"
  key_pair        = "${openstack_compute_keypair_v2.secret-keypair.name}"
  security_groups = ["default"]

  metadata {
    this = "centos 72 base"
  }

  network {
    name = "${openstack_networking_network_v2.n3_network.1.name}"
  }
}
