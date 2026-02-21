resource "aws_vpc" "my_vpc_01" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  
}

#creating the IGW
resource "aws_internet_gateway" "myvpc" {
  vpc_id = aws_vpc.my_vpc_01.id
}

#--------------------------------------------Start of Public Subnet Block----------------------------------------
#Creation of Public Subnet
resource "aws_subnet" "public_subnet_us-west-2a" {
  vpc_id = aws_vpc.my_vpc_01.id
  cidr_block        = var.public_subnet_cidr_2a
  availability_zone = "us-west-2a"
  tags = {
     Name = "Public Subnet_2a"
     AZ = "us-west-2a"
         }
}

resource "aws_subnet" "public_subnet_us-west-2b" {
  vpc_id = aws_vpc.my_vpc_01.id
  cidr_block        = var.public_subnet_cidr_2b
  availability_zone = "us-west-2b"
  tags = {
     Name = "Public Subnet_2b"
     AZ = "us-west-2b"
         }
}


#Creation of Routetable for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc_01.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myvpc.id # this has internet access 
  } 
  tags = {
    "Name" = "Public RT"
  }
}

#Association of RT to public subnet -2a
resource "aws_route_table_association" "associate_public_rt_2a" {
  subnet_id      = aws_subnet.public_subnet_us-west-2a.id
  route_table_id = aws_route_table.public_rt.id
}


#Association of RT to public subnet -2a
resource "aws_route_table_association" "associate_public_rt_2b" {
  subnet_id      = aws_subnet.public_subnet_us-west-2b.id
  route_table_id = aws_route_table.public_rt.id
}

#--------------------------------------------End of Public Subnet Block----------------------------------------

#--------------------------------------------Start of Private Subnet Block-------------------------------------

#Creation of Private Subnet
resource "aws_subnet" "private_subnet_us-west-2c" {
  vpc_id = aws_vpc.my_vpc_01.id
  cidr_block        = var.private_subnet_cidr_2c
  availability_zone = "us-west-2c"
  tags = {
     Name = "Private Subnet_2c"
     AZ = "us-west-2c"
         }
}

resource "aws_subnet" "private_subnet_us-west-2d" {
  vpc_id = aws_vpc.my_vpc_01.id
  cidr_block        = var.private_subnet_cidr_2d
  availability_zone = "us-west-2d"
  tags = {
     Name = "Private Subnet_2d"
     AZ = "us-west-2d"
         }
}



#Creation of Routetable for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc_01.id
  tags = {
    "Name" = "Private RT"
  }
  
}

#Association of RT to private subnet
resource "aws_route_table_association" "associate_private_rt_2c" {
  subnet_id      = aws_subnet.private_subnet_us-west-2c.id
  route_table_id = aws_route_table.private_rt.id
}

#Association of RT to private subnet
resource "aws_route_table_association" "associate_private_rt_2d" {
  subnet_id      = aws_subnet.private_subnet_us-west-2d.id
  route_table_id = aws_route_table.private_rt.id
}

#--------------------------------------------End of Private Subnet Block-------------------------------------

#--------------------------------------------Creation of NAT ------------------------------------------------

# resource "aws_instance" "nat_instance"{
#   ami                    = ""
#   availability_zone = "us-west-2a"
#   instance_type = "t2.micro"
#   key_name = var.aws_key_name
#   vpc_security_group_ids = 
# }

#--------------------------------------------Creation of Key Pair for Ec2 Instance---------------------

resource "aws_key_pair" "ec2-key" {
  key_name   = "ec2-key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ec2-key" {
    content  = tls_private_key.rsa.private_key_pem
    filename = "ec2key"
}

#--------------------------------------------Creation IAM ROle for session Manager---------------------

resource "aws_iam_role" "sessionmanagerrole" {
  name = "sessionmanagerrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.sessionmanagerrole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "session_profile" {
  name = "sessionmanagerprofile"
  role = aws_iam_role.sessionmanagerrole.name
}


#-----------------------------------------------------------------




#--------------------------------------------Creation of ec2 instance with public Subnet---------------------
resource "aws_instance" "web_instance" {
  ami           = "ami-075b5421f670d735c"
  instance_type = "t3.medium"
  key_name      = "ec2-key"

  subnet_id                   = aws_subnet.public_subnet_us-west-2a.id
  vpc_security_group_ids      = [aws_security_group.sg_webserver.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.session_profile.name

   user_data = null

  tags = {
    "Name" : "AmazonLInuxServer"
  }
}


#---------------------------Security Group ----------------------------------------

resource "aws_security_group" "sg_webserver" {
  name   = "Allowing http and SSH access from internet"
  vpc_id = aws_vpc.my_vpc_01.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}