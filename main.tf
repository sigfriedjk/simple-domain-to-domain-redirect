provider "aws" {
  region     = "us-east-1"
}

variable "left_host" {
  default = "source.com"
}

variable "right_host" {
  default = "target.com"
}

variable "hosted_zone" {
  default = "ABC123"
}

variable "environment" {
  default = "main"
}

locals {
  s3_origin_id = "myS3Origin"
  routing_rules = [{
      Condition = {
          "HttpErrorCodeReturnedEquals": "404"
      }
      Redirect ={
        HostName = "${var.right_host}",
        HttpRedirectCode = "301",
        Protocol = "http",
        ReplaceKeyWith = ""
      }
    }]
}


resource "aws_s3_bucket" "website_bucket" {
    bucket = "${var.left_host}"
    acl    = "public-read"
    
    website {
      index_document = "index.html"
      error_document = "error.html"
    
      routing_rules = "${jsonencode(local.routing_rules)}"
    }
}



resource "aws_s3_bucket" "logging_bucket" {
    bucket = "${var.left_host}-logging"
}


resource "aws_cloudfront_distribution" "redirect_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.website_bucket.website_endpoint}"
    origin_id   = "${local.s3_origin_id}"
    
    custom_origin_config {
      origin_protocol_policy = "http-only"
      https_port = 443
      http_port = 80
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "A CloudFront distribution for simple redirects"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "${aws_s3_bucket.logging_bucket.bucket_domain_name}"
    prefix          = "${var.environment}"
  }

  aliases = ["${var.left_host}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA"]
    }
  }

  tags = {
    Environment = "${var.environment}"
  }

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate.left_host_cert.arn}"
    ssl_support_method = "sni-only"
  }
}

resource "aws_route53_record" "cloudfront_record" {
  zone_id = "${var.hosted_zone}"
  name    = "${var.left_host}"
  type    = "A"
  alias {
    name                   = "${aws_cloudfront_distribution.redirect_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.redirect_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "left_host_cert" {
  domain_name       = "${var.left_host}"
  validation_method = "DNS"

  tags = {
    Environment = "${var.environment}"
  }

}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.left_host_cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.left_host_cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${var.hosted_zone}"
  records = ["${aws_acm_certificate.left_host_cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.left_host_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}