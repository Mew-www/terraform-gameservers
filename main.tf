/*
 * Provider definition
 *
 * pass credentials via Environment Variables
 * e.g. in Linux:
 * export AWS_ACCESS_KEY_ID="akeyid"
 * export AWS_SECRET_ACCESS_KEY="asecretkey"
 * export AWS_DEFAULT_REGION="eu-central-1"
 */

provider "aws" {}
# remote state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "gameservers-tfstate"
  versioning { enabled = true }
  lifecycle { prevent_destroy = true }
}
resource "aws_dynamodb_table" "terraform_state_lock" {
  name = "gameservers-tf-state"
  read_capacity = 1
  write_capacity = 1
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S" # string
  }
}
# remote state lookup
terraform {
  backend "s3" {
    encrypt = true
    bucket = "gameservers-tfstate"
    dynamodb_table = "gameservers-tf-state"
    key = "terraform.tfstate"
  }
}

/*
 * Variables
 */

variable "environment_tag" {
  description = "Environment tag"
  default = "Gameservers Environment"
}
variable "terraria_ec2_keyfile" {
  description = "Public RSA key path"
  default = "./id_rsa.pub"
}

/*
 * Save-files
 */
resource "aws_s3_bucket" "savefiles" {
  bucket = "gameservers-savefiles"
  acl = "public-read"
  versioning { enabled = false } # don't keep old savefiles by default, manually timestamp-version them if so
}

/*
 * Gaming VPC & internet connectivity
 */

# Isolated network for game servers, limited to a single region
resource "aws_vpc" "gaming_vpc" {
  cidr_block = "10.0.0.0/16" # 65'536 subnettable IP addresses
  tags = {
    Env = var.environment_tag
  }
}

# Connect gaming_vpc to the internet
resource "aws_internet_gateway" "gaming_vpc_gateway" {
  vpc_id = aws_vpc.gaming_vpc.id
  tags = {
    Env = var.environment_tag
  }
}

# Map all internet addresses to gaming_vpc's gateway
resource "aws_route_table" "public_gaming_vpc_routes" {
  vpc_id = aws_vpc.gaming_vpc.id
  route {
    cidr_block = "0.0.0.0/0" # public internet
    gateway_id = aws_internet_gateway.gaming_vpc_gateway.id
  }
  tags = {
    Name = "mytagged_vpcs_route_table"
    Env = var.environment_tag
  }
}

/*
 * Subnets
 */

# Isolated network for terraria server(s)
resource "aws_subnet" "terraria_subnet" {
  cidr_block = "10.0.0.0/24" # 256 available IP addresses
  vpc_id = aws_vpc.gaming_vpc.id
  map_public_ip_on_launch = false # define public IP addresses explicitly per instance
  tags = {
    Env = var.environment_tag
  }
}
# Connect terraria_subnet to the internet
resource "aws_route_table_association" "terraria_subnet_publification" {
  subnet_id = aws_subnet.terraria_subnet.id
  route_table_id = aws_route_table.public_gaming_vpc_routes.id
}

/*
 * Security groups / "Firewall rules sets" / Like iptables configs you can apply to multiple instances
 */

# Allow outbound traffic to any (including public) IP address
resource "aws_security_group" "security_group_allow_outbound" {
  name = "sg_allow_all_outbound"
  vpc_id = aws_vpc.gaming_vpc.id
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Env = var.environment_tag
  }
}

# Allow administration via SSH to/from servers, from any (including public) IP address
resource "aws_security_group" "security_group_administration" {
  name = "sg_tcp22"
  vpc_id = aws_vpc.gaming_vpc.id
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Env = var.environment_tag
  }
}

# Allow Terraria game client<=>server connections
resource "aws_security_group" "security_group_terraria_client" {
  name = "sg_tcp7777"
  vpc_id = aws_vpc.gaming_vpc.id
  ingress {
    from_port = 7777
    protocol = "tcp"
    to_port = 7777
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 7777
    protocol = "tcp"
    to_port = 7777
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Env = var.environment_tag
  }
}

/*
 * Server instances
 */


/*
# Use known keypair (with local pubkey) for ec2 SSH connections
resource "aws_key_pair" "terraria_administrator_ec2_keypair" {
  key_name = "terraria_ec2_key"
  public_key = file(var.terraria_ec2_keyfile)
}

# Maintain a static IP address to Soup Paradjis terraria server
resource "aws_eip" "soupparadjis_terraria_ip" {
  vpc = true
  tags = {
    URL = "soupparadijs.terraria.stringendo.io"
  }
}
# Create Soup Paradjis terraria server
resource "aws_instance" "soupparadjis_terraria_ec2" {
  ami = "ami-0b6d8a6db0c665fb7" # Ubuntu image AMI from https://cloud-images.ubuntu.com/locator/ec2/
  instance_type = "t2.small" # Details https://aws.amazon.com/ec2/pricing/on-demand/
  subnet_id = aws_subnet.terraria_subnet.id
  associate_public_ip_address = true # Explicitly associate a public IP address (since subnet default is false)
  vpc_security_group_ids = [
    aws_security_group.security_group_allow_outbound.id,
    aws_security_group.security_group_administration.id,
    aws_security_group.security_group_terraria_client.id
  ]
  iam_instance_profile = "CloudWatchAgentServerRole" # Enable CloudWatch Agent to send metrics (Disk, Memory)
  key_name = aws_key_pair.terraria_administrator_ec2_keypair.key_name
  tags = {
    Env = var.environment_tag
  }
}
resource "aws_eip_association" "soupparadjis_terraria_eip_assoc" {
  instance_id = aws_instance.soupparadjis_terraria_ec2.id
  allocation_id = aws_eip.soupparadjis_terraria_ip.id
}

output "soupparadjis_terraria_ip" {
  value = aws_instance.soupparadjis_terraria_ec2.public_ip
}
*/