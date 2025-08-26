resource "aws_s3_bucket" "website" {
  bucket = "${var.project_name}-frontend"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.default.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
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
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "default" {}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.default.iam_arn
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

data "local_file" "script" {
  filename = "${path.root}/../frontend/script.js"
}

resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.website.id
  key          = "script.js"
  content      = replace(data.local_file.script.content, "YOUR_API_GATEWAY_URL", var.api_gateway_url)
  content_type = "application/javascript"
  etag         = md5(replace(data.local_file.script.content, "YOUR_API_GATEWAY_URL", var.api_gateway_url))
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.root}/../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.root}/../frontend/index.html")
}

resource "aws_s3_object" "favicon" {
  bucket       = aws_s3_bucket.website.id
  key          = "favicon.ico"
  source       = "${path.root}/../frontend/favicon.ico"
  content_type = "image/x-icon"
  etag         = filemd5("${path.root}/../frontend/favicon.ico")
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.website.domain_name
}
