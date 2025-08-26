output "cloudfront_url" {
  description = "The URL of the CloudFront distribution."
  value       = module.frontend.cloudfront_url
}

output "api_gateway_url" {
  description = "The URL of the API Gateway."
  value       = module.backend.api_gateway_url
}
