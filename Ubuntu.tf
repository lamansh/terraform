provider "aws" {
  region = "eu-central-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "Debian1" {
key_name = "Debian1"
public_key = "${file("Debian1.pub")}"
}

resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.Debian1.key_name}"
  subnet_id ="${aws_subnet.test-vpc1-pub-sub1.id}"
  vpc_security_group_ids = "${aws_security_group.test-vpc1-pub-sg1.id}"
  tags {
    Name = "Ubuntu 16/04"
  }
}
  
resource "aws_ebs_volume" "example" {
  availability_zone = "eu-central-1b"
  size              = 10
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.example.id}"
  instance_id = "${aws_instance.web.id}"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_all"
  }
}

resource "aws_vpc" "test-vpc1" {
  cidr_block = "172.29.0.0/16"
  enable_dns_hostnames = "true"
  tags {
    Name = "test-vpc1"
  }
}

resource "aws_subnet" "test-vpc1-pub-sub1" {
  vpc_id = "${aws_vpc.my_vpc.id}"
  cidr_block = "172.29.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"
  tags {
    Name = "test-vpc1-pub-sub1"
  }
}

resource "aws_subnet" "test-vpc1-pr-sub1" {
  vpc_id = "${aws_vpc.my_vpc.id}"
  cidr_block = "172.29.2.0/24"
  availability_zone = "us-west-2b"
  tags {
    Name = "test-vpc1-pr-sub1"
  }
}

resource "aws_subnet" "test-vpc1-pub-sub2" {
  vpc_id = "${aws_vpc.my_vpc.id}"
  cidr_block = "172.29.3.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"
  tags {
    Name = "test-vpc1-pub-sub2"
  }
}

resource "aws_internet_gateway" "inet-gw" {
  vpc_id = "${aws_vpc.test-vpc1.id}"

  tags {
    Name = "inet-gw"
  }
}

resource "aws_eip" "natip" {
  instance = "${aws_instance.web.id}"
  vpc      = true
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = "${aws_eip.natip.id}"
  subnet_id     = "${aws_subnet.test-vpc1-pr-sub1.id}"

  tags {
    Name = "nat-gw"
  }
}

resource "aws_route_table" "test-vpc1-pub-rt1" {
  vpc_id = "${aws_vpc.test-vpc1.id}"

  route {
    cidr_block = "172.29.1.0/24"
    gateway_id = "${aws_internet_gateway.inet-gw.id}"
  }
  
  route {
    cidr_block = "172.29.3.0/24"
    gateway_id = "${aws_internet_gateway.inet-gw.id}"
  }  
  

  tags {
    Name = "test-vpc1-pub-rt1"
  }
}

resource "aws_route_table" "test-vpc1-pr-rt1" {
  vpc_id = "${aws_vpc.test-vpc1.id}"

  route {
    cidr_block = "172.29.2.0/24"
    gateway_id = "${aws_nat_gateway.nat-gw.id}"
  }
  
  tags {
    Name = "test-vpc1-pr-rt1"
  }
}

# test-vpc1-priv-rt1

resource "aws_security_group" "test-vpc1-pub-sg1" {
  name        = "test-vpc1-pub-sg1"
  description = "Allow all inbound traffic"

  ingress {
    security_groups = "${aws_security_group.test-vpc1-priv-sg1.id}"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    security_groups = "${aws_security_group.test-vpc1-priv-sg1.id}"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    
  }

  tags {
    Name = "test-vpc1-pub-sg1"
  }
  
  resource "aws_security_group" "test-vpc1-priv-sg1" {
  name        = "test-vpc1-priv-sg1"
  description = "Allow all inbound traffic"

  ingress {
    security_groups = "${aws_security_group.test-vpc1-pub-sg1.id}"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "test-vpc1-priv-sg1"
  }
}



resource "aws_network_interface" "if-vpc1-pub-sub1" {
  subnet_id = "${aws_subnet.test-vpc1-pub-sub1.id}"
  private_ips = ["172.16.10.100"]
  tags {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "foo" {
    ami = "ami-22b9a343" # us-west-2
    instance_type = "t2.micro"
    network_interface {
     network_interface_id = "${aws_network_interface.foo.id}"
     device_index = 0
  }
}