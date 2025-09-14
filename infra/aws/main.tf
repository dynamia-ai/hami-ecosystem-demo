provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = [
    cidrsubnet(var.vpc_cidr, 4, 0),
    cidrsubnet(var.vpc_cidr, 4, 1),
  ]
  private_subnets = [
    cidrsubnet(var.vpc_cidr, 4, 2),
    cidrsubnet(var.vpc_cidr, 4, 3),
  ]

  # GPU node group configurations
  gpu_node_group_configs = {
    t4 = {
      name            = "t4"
      ami_type        = "AL2_x86_64_GPU"
      instance_types  = ["g4dn.12xlarge"]
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      max_size        = 1
      desired_size    = 1
      disk_size       = 100
      use_custom_launch_template = false
      labels = {
        "gpu"         = "on"
        "accelerator" = "t4"
      }
    }
    
    a10g = {
      name            = "a10g"
      ami_type        = "AL2_x86_64_GPU"
      instance_types  = ["g5.12xlarge"]
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      max_size        = 1
      desired_size    = 1
      disk_size       = 100
      use_custom_launch_template = false
      labels = {
        "gpu"         = "on"
        "accelerator" = "a10g"
      }
    }
    
    v100 = {
      name            = "v100"
      ami_type        = "AL2_x86_64_GPU"
      instance_types  = ["p3.8xlarge"]  # 4x V100 GPUs
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      disk_size       = 100
      use_custom_launch_template = false
      labels = {
        "gpu"         = "on"
        "accelerator" = "v100"
      }
    }
  }

  # Generate the final node groups configuration
  eks_managed_node_groups = {
    for gpu_type in var.enabled_gpu_node_groups : gpu_type => merge(
      local.gpu_node_group_configs[gpu_type],
      try(var.node_group_overrides[gpu_type], {})
    )
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "Project" = var.cluster_name
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_public_access  = true
  enable_irsa                     = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  eks_managed_node_groups = local.eks_managed_node_groups

  tags = {
    "Project" = var.cluster_name
  }
}

# --- Helm provider configured to connect to this EKS cluster ---
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = [
        "eks",
        "get-token",
        "--region", var.region,
        "--cluster-name", module.eks.cluster_name,
      ]
    }
  }
}

# --- Install HAMi via Helm into kube-system ---
resource "helm_release" "hami" {
  name             = "hami"
  repository       = "https://project-hami.github.io/HAMi/"
  chart            = "hami"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true

  # Ensure the cluster and aws-auth are ready before installing
  depends_on = [module.eks]
}
