
resource "aws_s3_bucket" "website_bucket" {
  #bucket = var.bucket_names_list[0]
  bucket = "${var.environment}-${var.project_name}-website-bucket"

  tags = {
    Name        = "${var.environment}-${var.project_name}-website-bucket"
    Environment = var.environment
  }

}

# by default buckets are private but add this just to be explicit
resource "aws_s3_bucket_public_access_block" "website_bucket_public_access_block" {
  # adding bucket param is an implicit "depends_on" and ensures that the public access block is added/implemented after the 
  # bucket is created
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  # adding bucket param and adding aws s3 bucket public access block to depends on param here
  # ensure that this policy will be created after the bucket and the public access block on the bucket
  # adding the bucket param is an implicit "depends_on"
  bucket     = aws_s3_bucket.website_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.website_bucket_public_access_block]

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontServicePrincipal",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : [
          "s3:GetObject"
        ],
        "Resource" : "${aws_s3_bucket.website_bucket.arn}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}



resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.environment}-${var.project_name}-oac"
  description                       = "OAC for ${var.environment}-${var.project_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_object" "object" {

  for_each = fileset("${path.module}/../frontend/dist", "**/*")
  bucket   = aws_s3_bucket.website_bucket.id
  key      = each.value
  source   = "${path.module}/../frontend/dist/${each.value}"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("${path.module}/../frontend/dist/${each.value}")

  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml",
    "ico"  = "image/x-icon",
    "txt"  = "text/plain"
    },
    split(".", each.value)[length(split(".", each.value)) - 1],
    "application/octet-stream"
  )
}

locals {
  origin_id = "S3-${aws_s3_bucket.website_bucket.id}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = local.origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  #aliases = ["mysite.${local.my_domain}", "yoursite.${local.my_domain}"]

  default_cache_behavior {
    #allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    #viewer_protocol_policy = "allow-all"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400 # ttl are the times the data will be cached in the edge locations
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      # restriction_type = "whitelist"
      # locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "test"
  }

  # viewer_certificate {
  #   # acm_certificate_arn = data.aws_acm_certificate.my_domain.arn
  #   # ssl_support_method  = "sni-only"
  #   cloudfront_default_certificate = true
  # }

  # Add your alternate subdomains here
  aliases = ["app.${var.domain_name}"]

  viewer_certificate {
    cloudfront_default_certificate = false
    # Changing this to reference the validation resource forces the correct dependency order (implicit validation)
    acm_certificate_arn = aws_acm_certificate_validation.app_subdomain_cert_validation.certificate_arn
    #acm_certificate_arn            = aws_acm_certificate.app_subdomain_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

output "website_url" {
  description = "The URL of the website served via CloudFront"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

########################################################################## cntd
variable "domain_name" {
  default = "rooteddata.org"
}

######## acm certificate

resource "aws_acm_certificate" "app_subdomain_cert" {
  domain_name       = "app.${var.domain_name}"
  validation_method = "DNS"

  # use the alias us-east-1 provider set up just for certificates because cloudfront always runs in us east 1 and required cert to be created in us east 1
  provider = aws.us_east_1

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }

}

# This resource forces Terraform to wait until validation is successful
resource "aws_acm_certificate_validation" "app_subdomain_cert_validation" {
  certificate_arn = aws_acm_certificate.app_subdomain_cert.arn

  # use the alias us-east-1 provider set up just for certificates because cloudfront always runs in us east 1 and required cert to be created in us east 1
  provider = aws.us_east_1

  # Normally you pass route53 records here, but since you are using Namecheap,
  # leave the `validation_record_fqdns` argument OUT completely.
}

# Output the CNAME values needed for ACM validation
output "acm_validation_records" {
  value = {
    for dvo in aws_acm_certificate.app_subdomain_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

########

# # Create the completely separate subdomain hosted zone
# resource "aws_route53_zone" "app_subdomain_zone" {
#   name = "app.${var.domain_name}"
# }

# # Output the name servers you need to copy to your external provider
# output "app_subdomain_name_servers" {
#   value       = aws_route53_zone.app_subdomain_zone.name_servers
#   description = "Manually add these 4 NS records to your external parent domain DNS settings."
# }


########

# resource "aws_route53_zone" "main" {
#   name = var.domain_name
# }

# resource "aws_route53_zone" "dev" {
#   name = "dev.example.com"

#   tags = {
#     Environment = "dev"
#   }
# }

# resource "aws_route53_record" "dev-ns" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "dev.example.com"
#   type    = "NS"
#   ttl     = "30"
#   records = aws_route53_zone.dev.name_servers
# }




