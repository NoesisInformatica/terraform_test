# Test example
variable "external_gateway" {
	default = "893a5b59-081a-4e3a-ac50-1e54e262c3fa"
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
resource "openstack_compute_keypair_v2" "test-keypair" {
  name       = "my-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC0FExXQUizEmIyLWPAFzYxAX7okTvae+ZIqYGrUkYFtu6qoymnewfaCI78s9qD+vxNqZhT1FtKnlUqnxlR/yrElUD/LYKm/bBjpdWzRcQJOioLOWSGSzjIG4kXORA8c996WRNLM9OlGgtLTdQU7f60+f9s77pmSm3OEs/mwsx2UssR77Y8Q5ZYzEZO3yq8Ocg9I5SscVmjy63vvOXWNX1ImLTKsSw3zdtLLqtt38sufnaExsXrFQnBmrdg5VktckBujjy4prhSHpY6SMZOpozujwAKd9T+tpcjMg1lE3dTJiDN8cvpF6mpKiSbzDW1cFcHBjL340aoZ4NEJi/L8xoJOtR90c+e/l+66mSRu0gROhTy2uKfLoXLFcNGz09HdaAltjpktw4Lxh6WGiSDPfgr3fq6yqzyvqZAZh2XXP4NSkLQvPmYAsV0na4CwTXVUBcMD45UJmKzevO2mSIyy5f/Ww+nmMhcnIKKCCoox0WeEgoVLUcdp3fXqv8QlzdJdFK1e40L1aerTARKE15JuJxjcFU+20zGADx8/yyI5ifh51KIAQmN1ZwSzMlKBsSFVP++ZS6rSxXXOJzZ+kdyjFTulHvbs7TY+iChzme/UYDVtmoNYqljOlTEm0DvrvGkg264rgKtd9obZyZ8PVdWVEx5Fw/t8PeVU0F7h3HcXsvnWQ=="
}