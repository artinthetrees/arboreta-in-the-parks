# ==============================================================================
# CUSTOM NON-DEFAULT NETWORKING INFRASTRUCTURE
# ==============================================================================

# # Fetch the default VPC to launch infrastructure
# data "aws_vpc" "default" {
#   default = true
# }

# # Fetch default subnets for the instance placement
# data "aws_subnets" "default" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.default.id]
#   }
# }

# locals {
#   first_subnet_id = data.aws_subnets.default.ids[0]
# }

# Create the Custom Isolated VPC
resource "aws_vpc" "custom_vpc" {
  #cidr_block           = "10.100.0.0/16"
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-${var.project_name}-custom-vpc"
    Environment = var.environment
  }
}

# Create an Internet Gateway (Required to make the subnet public for your Elastic IP)
resource "aws_internet_gateway" "custom_igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-custom-igw"
    Environment = var.environment
  }
}

# Create a Custom Public Subnet for EC2 Placement
resource "aws_subnet" "custom_public_subnet" {
  vpc_id = aws_vpc.custom_vpc.id
  #cidr_block              = "10.100.1.0/24"
  # Math: Carves out the very first /24 block (10.0.0.0/24) from the /16 VPC
  cidr_block              = cidrsubnet(aws_vpc.custom_vpc.cidr_block, 8, 0)
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true # Automatically requests public setup behavior

  tags = {
    Name        = "${var.environment}-${var.project_name}-public-subnet-1a"
    Environment = var.environment
  }
}

# Create a Public Route Table pointing to the Internet Gateway
resource "aws_route_table" "custom_public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_igw.id
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Bind the Route Table to your Custom Subnet
resource "aws_route_table_association" "custom_public_assoc" {
  subnet_id      = aws_subnet.custom_public_subnet.id
  route_table_id = aws_route_table.custom_public_rt.id
}

# ==============================================================================
# EC2 INSTANCE CONNECT ENDPOINT SETUP (CUSTOM VPC)
# ==============================================================================

## EC2 Instance Connect Endpoint ##
## EC2 Instance Connect Endpoint Security Group ##

# Create a security group dedicated strictly to the EICE proxy
resource "aws_security_group" "eice_sg" {
  name_prefix = "eice-security-group-"
  description = "Controls access for EC2 Instance Connect Endpoint"
  #vpc_id      = data.aws_vpc.default.id
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-eice-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_egress_rule" "eice_to_vpc_ssh" {
  security_group_id = aws_security_group.eice_sg.id

  # Allows the endpoint to send SSH traffic out to instances inside the VPC CIDR
  #cidr_ipv4   = data.aws_vpc.default.cidr_block
  cidr_ipv4   = aws_vpc.custom_vpc.cidr_block
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# Deploy the EICE Endpoint proxy into your chosen subnet
resource "aws_ec2_instance_connect_endpoint" "eice_for_custom_vpc" {
  subnet_id          = aws_subnet.custom_public_subnet.id
  security_group_ids = [aws_security_group.eice_sg.id]

  tags = {
    Name        = "${var.environment}-${var.project_name}-eice-for-custom-vpc"
    Environment = var.environment
  }
}

## EC2 Security Groups ##
## NOTE: need multiple because max 60 rules per group, each prefix counts as a rule, 55 cloudfront prefixes (used to restrict http/https ipv4 and ivp6 - 55 x 4), 2 ec2 instance connect prefixes (used to restrict ssh)
## NOTE: max of 5 security groups allowed per EC2 instance
## NOTE: max of 1000 security group rules allowed per EC2 instance across all attached security groups

# Fetch the AWS-managed CloudFront Prefix Lists - 
# getting these to limit incoming http/https traffic to cloudfront prefixes

# this is a list of 55 prefixes - only 60 allowed per security group
data "aws_ec2_managed_prefix_list" "cloudfront_ipv4" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# this is a list of 55 prefixes - only 60 allowed per security group
data "aws_ec2_managed_prefix_list" "cloudfront_ipv6" {
  name = "com.amazonaws.global.ipv6.cloudfront.origin-facing"
}

# getting these to limit incoming ssh traffic to ec2 instance connect prefixes

# this is a list of 2 prefixes - only 60 allowed per security group
data "aws_ec2_managed_prefix_list" "instance_connect" {
  name = "com.amazonaws.${var.region}.ec2-instance-connect"
}

# EC2 Security Group 1: SSH ingress and egress
resource "aws_security_group" "ec2_sg_ssh_and_egress" {
  name_prefix = "ec2-sg-ssh-and-egress-"
  description = "Allow incoming SSH traffic restricted to ec2 instance connect prefixes; Allow all outgoing traffic"
  #vpc_id      = data.aws_vpc.default.id
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sg-ssh-and-egress"
    Environment = var.environment
  }
}

# EC2 Security Group 2: HTTP ivp4
resource "aws_security_group" "ec2_sg_http_ipv4" {
  name_prefix = "ec2-sg-http-ipv4-"
  description = "Allow incoming HTTP ipv4 traffic restricted to cloudfront prefixes"
  #vpc_id      = data.aws_vpc.default.id
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sg-http-ipv4"
    Environment = var.environment
  }
}

# EC2 Security Group 3: HTTP ivp6
resource "aws_security_group" "ec2_sg_http_ipv6" {
  name_prefix = "ec2-sg-http-ipv6-"
  description = "Allow incoming HTTP ipv6 traffic restricted to cloudfront prefixes"
  #vpc_id      = data.aws_vpc.default.id
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sg-http-ipv6"
    Environment = var.environment
  }
}

# EC2 Security Group 4: HTTPS ivp4
resource "aws_security_group" "ec2_sg_https_ipv4" {
  name_prefix = "ec2-sg-https-ipv4-"
  description = "Allow incoming HTTPS ipv4 traffic restricted to cloudfront prefixes"
  #vpc_id      = data.aws_vpc.default.id
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sg-https-ipv4"
    Environment = var.environment
  }
}

# EC2 Security Group 5: HTTPS ivp6
resource "aws_security_group" "ec2_sg_https_ipv6" {
  name_prefix = "ec2-sg-https-ipv6-"
  description = "Allow incoming HTTPS ipv6 traffic restricted to cloudfront prefixes"
  #vpc_id      = data.aws_vpc.default.id
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sg-https-ipv6"
    Environment = var.environment
  }
}

# Rule 1: SSH from EICE only
# resource "aws_vpc_security_group_ingress_rule" "ssh_ec2_instance_connect" {
#   #security_group_id = aws_security_group.ec2_sg_ssh.id
#   security_group_id = aws_security_group.ec2_sg_ssh_and_egress.id
#   description       = "SSH from EC2 Instance Connect"
#   from_port         = 22
#   to_port           = 22
#   ip_protocol       = "tcp"
#   prefix_list_id    = data.aws_ec2_managed_prefix_list.instance_connect.id

#   tags = {
#     Name        = "${var.environment}-${var.project_name}-ec2-sgr-ingress-ssh"
#     Environment = var.environment
#   }
# }

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_eice" {
  # EC2 security group
  security_group_id = aws_security_group.ec2_sg_ssh_and_egress.id

  # EICE security group - referenced_security_group_id holds the id of the source security group that is referenced in the rule.
  referenced_security_group_id = aws_security_group.eice_sg.id

  description = "SSH from EC2 Instance Connect Endpoint"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sgr-ingress-ssh"
    Environment = var.environment
  }
}

# Rule 2: HTTP (Port 80) from CloudFront IPv4 Edge Locations
resource "aws_vpc_security_group_ingress_rule" "http_cloudfront_ipv4" {
  security_group_id = aws_security_group.ec2_sg_http_ipv4.id
  description       = "HTTP from CloudFront IPv4"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_ipv4.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sgr-ingress-http-ipv4"
    Environment = var.environment
  }
}

# Rule 3: HTTP (Port 80) from CloudFront IPv6 Edge Locations
resource "aws_vpc_security_group_ingress_rule" "http_cloudfront_ipv6" {
  security_group_id = aws_security_group.ec2_sg_http_ipv6.id
  description       = "HTTP from CloudFront IPv6"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_ipv6.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sgr-ingress-http-ipv6"
    Environment = var.environment
  }
}

# Rule 4: HTTPS (Port 443) from CloudFront IPv4 Edge Locations
resource "aws_vpc_security_group_ingress_rule" "https_cloudfront_ipv4" {
  security_group_id = aws_security_group.ec2_sg_https_ipv4.id
  description       = "HTTPS from CloudFront IPv4"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_ipv4.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sgr-ingress-https-ipv4"
    Environment = var.environment
  }
}

# Rule 5: HTTPS (Port 443) from CloudFront IPv6 Edge Locations
resource "aws_vpc_security_group_ingress_rule" "https_cloudfront_ipv6" {
  security_group_id = aws_security_group.ec2_sg_https_ipv6.id
  description       = "HTTPS from CloudFront IPv6"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_ipv6.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sgr-ingress-https-ipv6"
    Environment = var.environment
  }
}

# Rule 6: Outbound (Allow all traffic out)
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  #security_group_id = aws_security_group.ec2_sg_egress.id
  security_group_id = aws_security_group.ec2_sg_ssh_and_egress.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-sgr-egress"
    Environment = var.environment
  }
}

# # Security group mapping ingress/egress rules
# resource "aws_security_group" "ec2_sg" {
#   #name        = "ec2-web-sg"
#   name_prefix = "ec2-web-sg-"
#   description = "Allow incoming SSH, HTTP, and HTTPS traffic"
#   vpc_id      = data.aws_vpc.default.id

#   ingress {
#     description = "SSH from anywhere"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "HTTP from anywhere"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "HTTPS from anywhere"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name        = "${var.environment}-${var.project_name}-ec2-security-group"
#     Environment = var.environment
#   }
# }

# ==============================================================================
# 3. ACCESS KEY & EC2 COMPUTATION
# ==============================================================================

# Launch the compute instance
resource "aws_instance" "web_server" {
  #ami           = data.aws_ami.amazon_linux.id
  ami           = var.ami_id
  instance_type = var.ec2_instance_type
  # TODO: should no longer need this if using ec2 instance connect to ssh - as it provides temp ssh keys instead - 
  # ```aws ec2-instance-connect ssh --instance-id i-0123456789abcdef0 --connection-type eice --private-key-file "path_to_private_key"```
  # however it seems like there are several issues with this:
  # - normal function is to not set the private key file param as above, as this fx should generate an ephemeral key which it pushes to ec2
  # - however, apparently a known issue on windows that it stores the ephemeral generated key in a temp folder with permissive permissions and the fx requires strict permissions so rejects these keys
  # - solution is to generate your own key locally, set strict permissions, and set the private key file param with the path to this key
  # - in this case (i think) what is supposed to happen is that the fx sends the public key corresponding to the private key specified ephemerally to the ec2 and then authenticates with the matching private key specified
  # - this seemed to be working but it turns out that it was not - it was only working because i had originally set the key_name param of the ec2 instance to the key pair i have locally and also added as an ec2 key pair on aws console
  # - this means that the fx is not ephemerally pushing the key pair to the ec2; instead, it's already there at creation of ec2 from def of key_name and stays there all the time
  # - this still provides i think substantially more security than having fully open ssh but should troubleshoot this issue of not being able to ephemerally push ssh key pair from local to ec2
  # NOTE: some additional research suggests that the issue with sending the key from local is that the ssh file structure is not set up on ec2 if no key_name is specified (e.g. the ssh folder with the authorized_keys file inside, and set with proper strict permissions)
  # so seems like possibly a good approach would be instead of specifying a key_name to have a startup script for the ec2 (e.g. via user_data) that sets this infra up
  key_name = var.ec2_key_name

  # # Injecting the startup automation block
  # #user_data = file("${path.module}/setup-volume.sh")
  # # Enforce cleartext boundary mapping via native base64 pipeline
  user_data_base64            = filebase64("${path.module}/setup-volume.sh")
  user_data_replace_on_change = true

  vpc_security_group_ids = [
    aws_security_group.ec2_sg_ssh_and_egress.id,
    aws_security_group.ec2_sg_http_ipv4.id,
    aws_security_group.ec2_sg_http_ipv6.id,
    aws_security_group.ec2_sg_https_ipv4.id,
    aws_security_group.ec2_sg_https_ipv6.id
  ]
  subnet_id = aws_subnet.custom_public_subnet.id

  # let's see if this is required - for now first deal with the issue that the new ec2 is a different ami id
  # root_block_device {
  #   volume_type           = "gp3"
  #   volume_size           = 20 # default for t2.micro linux is 8GB; 8cents per extra GB per month; so adding 12GB means about an extra dollar per month 
  #   delete_on_termination = true
  # }

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-instance"
    Environment = var.environment
    AllowSSH    = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Separate EBS Volume for Postgres Data
resource "aws_ebs_volume" "postgres_data" {
  availability_zone = aws_instance.web_server.availability_zone
  size              = 10
  type              = "gp3"

  tags = {
    Name        = "${var.environment}-${var.project_name}-postgres-db-volume"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true # Blocks 'terraform destroy' from tearing down the volume
  }
}

# Attach EBS Volume to the Instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdf" # for later ami may have to calculate this dynamically
  volume_id   = aws_ebs_volume.postgres_data.id
  instance_id = aws_instance.web_server.id
}


# Bind a static public EIP context to the instance
# UPDATE: instead of hardcoding the association within the eip definition, add an explicit association resource 
# - this allows the same eip to be detached from the old instance and attached to the new when updating the 
# instance in a way that requires destroy and recreate
resource "aws_eip" "web_eip" {
  # UPDATE: comment this out - instead of hard-coding this association, use an explicit association resource
  # instance = aws_instance.web_server.id
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-eip"
    Environment = var.environment
  }

}

# Explicit Association resource
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web_server.id
  allocation_id = aws_eip.web_eip.id

  # This allows Terraform to detach from the old EC2 
  # and attach to the new EC2.
  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# ROUTE 53 DNS & SSL CERTIFICATE (ACM)
# ==============================================================================

# Reference the existing hosted zone
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

# Request an SSL Certificate in us-east-1 for CloudFront compatibility
resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = var.subdomain_name
  validation_method = "DNS"

  tags = {
    Name        = "${var.environment}-${var.project_name}-acm-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create validation DNS records in Route 53 - these are generally cname records that prove to the certificate authority that you own the domain you're requesting a certificate for
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

# Explicitly wait for ACM validation completion handshake
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ==============================================================================
# CLOUDFRONT DISTRIBUTION
# ==============================================================================
# Fetch the managed CachingDisabled policy by its name
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# data "aws_cloudfront_cache_policy" "caching_optimized" {
#   name = "Managed-CachingOptimized"
# }

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# data "aws_cloudfront_origin_request_policy" "all_viewer" {
#   name = "Managed-AllViewer"
# }

resource "aws_cloudfront_distribution" "cdn" {
  comment = "CDN Fronting the EC2 Instance"

  origin {
    domain_name = aws_eip.web_eip.public_dns
    origin_id   = "EC2-ElasticIP-Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # Change to "match-viewer" if EC2 runs SSL locally
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # ADD THIS: CloudFront injects the domain name safely into a custom header
    custom_header {
      name  = "X-Forwarded-Host"
      value = var.subdomain_name # e.g., backend-dev.rooteddata.org
    }

    # ADD THIS: A secret header used to identify genuine CloudFront requests
    custom_header {
      name  = "X-Origin-Verify"
      value = var.cloudfront_secret_token # Store this in an env var or secrets manager
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.subdomain_name]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    #allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "EC2-ElasticIP-Origin"

    # # Pass the ID from the data source
    #cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id

    # COMPLETELY DISABLE CACHING FOR THE BACKEND API
    # Uses AWS Managed Policy: CachingDisabled (4135ea2d-6df8-44a3-9df3-4b5a84be39ad)
    # cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # FORWARD ALL HEADERS, COOKIES, & QUERY STRINGS EXCEPT THE HOST HEADER
    # Uses AWS Managed Policy: AllViewerExceptHostHeader (b689b0a8-53d0-40ab-baf2-68002d296205)
    # This sends Origin, Authorization, and Referer straight to Django for security validation
    # origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68002d296205"


    # forwarded_values {
    #   query_string = true
    #   headers      = ["Host", "Authorization", "Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"] # Pass Host header so EC2 handles multi-site routing if needed

    #   cookies {
    #     forward = "all"
    #   }
    # }

    viewer_protocol_policy = "redirect-to-https"
    # min_ttl                = 0
    # default_ttl            = 3600
    # max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}-cdn"
    Environment = var.environment
  }
}

# ==============================================================================
# ROUTE 53 ALIAS TARGET LINK
# ==============================================================================

# Route custom subdomain traffic straight into CloudFront edge caches
resource "aws_route53_record" "subdomain_alias" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.subdomain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }

}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "ec2_id" {
  value       = aws_instance.web_server.id
  description = "AWS EC2 instance ID - use to ssh in using ec2 instance connect endpoint instead of public IP"
}

output "ec2_public_ip" {
  value       = aws_eip.web_eip.public_ip
  description = "The allocated static Elastic IP binding of the server"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "The default direct AWS cloudfront edge url topology"
}

output "app_url" {
  value       = "https://${var.subdomain_name}"
  description = "The application address entry point"
}



