provider "aws" {
  region = var.aws_region
}

provider "tls" {}

provider "random" {}

# First create the shared VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "shared-vpc-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
  }
}

# Then create Jenkins
module "jenkins" {
  source = "./modules/jenkins"

  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.public_subnets[0]
  environment         = var.environment
  key_name            = aws_key_pair.jenkins_key.key_name
  admin_cidr_blocks   = var.admin_cidr_blocks
  # allowed_outbound_cidr_blocks = ["0.0.0.0/0"]  # Optional: uncomment to override default
  
  tags = {
    Environment = var.environment
    Project     = "shared-infrastructure"
    Terraform   = "true"
  }
}

# Finally create CodeQL
module "codeql" {
  source = "./modules/codeql"

  vpc_id                    = module.vpc.vpc_id
  subnet_id                 = module.vpc.public_subnets[1]
  environment              = var.environment
  key_name                 = aws_key_pair.jenkins_key.key_name
  allowed_ssh_cidr_blocks  = [
    format("%s/32", module.jenkins.jenkins_master_private_ip),
    "73.202.208.108/32"  # Your IP address
  ]
  allowed_http_cidr_blocks = [format("%s/32", module.jenkins.jenkins_master_private_ip)]
  allowed_https_cidr_blocks = [format("%s/32", module.jenkins.jenkins_master_private_ip)]
}