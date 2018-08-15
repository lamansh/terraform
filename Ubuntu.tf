provider "aws" {
  region = "eu-central-1"
  access_key = "AKIAIR6WVHNCPVGC7PXQ"
  secret_key = ""
  
}

variable "region" {
  default = "eu-central-1"
}
variable "availability_zone" {
  default = "eu-central-1a"
  
}
resource "aws_key_pair" "Ubuntu" {
key_name = "Ubuntu"
public_key = "${file("Ubuntu.pub")}"
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

resource "aws_vpc" "test-vpc1" {
  cidr_block = "172.29.0.0/16"
  enable_dns_hostnames = "true"
  tags {
    Name = "test-vpc1"
  }
}

resource "aws_subnet" "test-vpc1-pub-sub1" {
  vpc_id = "${aws_vpc.test-vpc1.id}"
  cidr_block = "172.29.1.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${var.availability_zone}"
  depends_on = ["aws_internet_gateway.inet-gw"]
  tags {
    Name = "test-vpc1-pub-sub1"
  }
}

resource "aws_subnet" "test-vpc1-pr-sub1" {
  vpc_id = "${aws_vpc.test-vpc1.id}"
  cidr_block = "172.29.2.0/24"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = false
  tags {
    Name = "test-vpc1-pr-sub1"
  }
}

resource "aws_subnet" "test-vpc1-pub-sub2" {
  vpc_id = "${aws_vpc.test-vpc1.id}"
  cidr_block = "172.29.3.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${var.availability_zone}"
  depends_on = ["aws_internet_gateway.inet-gw"]
  tags {
    Name = "test-vpc1-pub-sub2"
  }
}

resource "aws_instance" "web" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.Ubuntu.key_name}"
  subnet_id ="${aws_subnet.test-vpc1-pub-sub1.id}"
  depends_on = ["aws_security_group.test-vpc1-pub-sg1"]
  vpc_security_group_ids = ["${aws_security_group.test-vpc1-pub-sg1.id}"]
  tags {
    Name = "web"
  }
}

resource "aws_instance" "web1" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.Ubuntu.key_name}"
  subnet_id ="${aws_subnet.test-vpc1-pub-sub2.id}"
  depends_on = ["aws_security_group.test-vpc1-pub-sg1"]
  vpc_security_group_ids = ["${aws_security_group.test-vpc1-pub-sg1.id}"]
  tags {
    Name = "web1"
  }
}
 resource "aws_instance" "web2" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.Ubuntu.key_name}"
  subnet_id ="${aws_subnet.test-vpc1-pr-sub1.id}"
  depends_on = ["aws_security_group.test-vpc1-priv-sg1"]
  vpc_security_group_ids = ["${aws_security_group.test-vpc1-priv-sg1.id}"]
  tags {
    Name = "web2"
  }
}

resource "aws_internet_gateway" "inet-gw" {
  vpc_id = "${aws_vpc.test-vpc1.id}"

  tags {
    Name = "inet-gw"
  }
}

resource "aws_eip" "natip" {
  #instance = "${aws_instance.web.id}"
  #associate_with_private_ip = "${aws_network_interface.if-vpc1-pub-sub1.private_ips}"
  vpc      = true
  depends_on = ["aws_internet_gateway.inet-gw"]
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = "${aws_eip.natip.id}"
  subnet_id     = "${aws_subnet.test-vpc1-pub-sub1.id}"
  depends_on = ["aws_internet_gateway.inet-gw"]
  tags {
    Name = "nat-gw"
  }
}

resource "aws_route_table" "test-vpc1-pub-rt1" {
  vpc_id = "${aws_vpc.test-vpc1.id}"


  route {
  cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.inet-gw.id}"
  }
  

  tags {
    Name = "test-vpc1-pub-rt1"
  }
}

resource "aws_route_table" "test-vpc1-pr-rt1" {
  vpc_id = "${aws_vpc.test-vpc1.id}"

  route {
    cidr_block = "0.0.0.0/0"
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
  vpc_id = "${aws_vpc.test-vpc1.id}"

  ingress {
    #security_groups = "${aws_security_group.test-vpc1-priv-sg1.id}"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    #security_groups = "${aws_security_group.test-vpc1-priv-sg1.id}"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    
  }

  tags {
    Name = "test-vpc1-pub-sg1"
  }
}
  
  resource "aws_security_group" "test-vpc1-priv-sg1" {
  name        = "test-vpc1-priv-sg1"
  description = "Allow all inbound traffic"
  vpc_id = "${aws_vpc.test-vpc1.id}"
  ingress {
    #security_groups = "${aws_security_group.test-vpc1-pub-sg1.id}"
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
  private_ips = ["172.29.1.100"]
  security_groups = ["${aws_security_group.test-vpc1-pub-sg1.id}"]
  tags {
    Name = "primary_network_interface"
  }
    attachment {
    instance     = "${aws_instance.web.id}"
    device_index = 1
  }
}

resource "aws_network_interface" "if-vpc1-pr-sub1" {
  subnet_id = "${aws_subnet.test-vpc1-pr-sub1.id}"
  private_ips = ["172.29.2.100"]
  security_groups = ["${aws_security_group.test-vpc1-priv-sg1.id}"]
  tags {
    Name = "primary_network_interface"
  }
    attachment {
    instance     = "${aws_instance.web1.id}"
    device_index = 1
  }
}

resource "aws_network_interface" "if-vpc1-pub-sub2" {
  subnet_id = "${aws_security_group.test-vpc1-pub-sg1.id}"
  private_ips = ["172.29.3.100"]
  security_groups = ["${aws_route_table.test-vpc1-pub-rt1.id}"]
  tags {
    Name = "primary_network_interface"
  }
    attachment {
    instance     = "${aws_instance.web2.id}"
    device_index = 1
  }
}

