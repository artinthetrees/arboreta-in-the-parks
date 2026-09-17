# NOTE: 
# as part of artinthetrees-infra (general infrastructure), already manually created an ssh key pair and imported it as ec2 key pair into us-east-2 region

# get ec2 ssh key pair already imported into aws by its name
data "aws_key_pair" "ec2_key" {
  key_name           = var.ec2_key_name
  include_public_key = false
}

# ==============================================================================
# NETWORKING & SECURITY GROUPS
# ==============================================================================

# Fetch the default VPC to launch infrastructure
data "aws_vpc" "default" {
  default = true
}

# Fetch default subnets for the instance placement
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group mapping ingress/egress rules
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-web-sg"
  description = "Allow incoming SSH, HTTP, and HTTPS traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-security-group"
    Environment = var.environment
  }
}

# ==============================================================================
# 3. ACCESS KEY & EC2 COMPUTATION
# ==============================================================================

# # Local public key path mapping
# resource "aws_key_pair" "deployer" {
#   key_name   = "deployer-key"
#   public_key = file("~/.ssh/id_rsa.pub")
# }

# Fetch latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Launch the compute instance
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.ec2_instance_type
  #key_name               = aws_key_pair.deployer.key_name
  key_name               = data.aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-instance"
    Environment = var.environment
  }
}

# Bind a static public EIP context to the instance
resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"

  tags = {
    Name        = "${var.environment}-${var.project_name}-ec2-eip"
    Environment = var.environment
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
# data "aws_cloudfront_cache_policy" "caching_disabled" {
#   name = "Managed-CachingDisabled"
# }

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

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
  }

  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.subdomain_name]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    #allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "EC2-ElasticIP-Origin"

    # # Pass the ID from the data source
    # cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    # origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id


    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"] # Pass Host header so EC2 handles multi-site routing if needed

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
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



