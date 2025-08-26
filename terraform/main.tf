provider "aws" {
  region = var.aws_region
}

provider "local" {}

module "backend" {
  source = "./modules/backend"
  project_name = var.project_name
  aws_region = var.aws_region
}

module "frontend" {
  source = "./modules/frontend"
  api_gateway_url = module.backend.api_gateway_url
  project_name = var.project_name
}


