# Import base providers and setup from root
provider "aws" {
  region = var.aws_region
}

provider "tls" {}

provider "random" {}

# Reference the shared modules
module "base_infrastructure" {
  source = "../../main"

  environment         = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  admin_cidr_blocks  = var.admin_cidr_blocks
} 