variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
  default     = "hami-demo-aws"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enabled_gpu_node_groups" {
  description = "List of GPU node groups to enable"
  type        = list(string)
  default     = ["t4", "a10g"]
  # default     = ["t4","v100"]
}

variable "node_group_overrides" {
  description = "Override configurations for specific node groups"
  type = map(object({
    min_size     = optional(number)
    max_size     = optional(number)
    desired_size = optional(number)
    disk_size    = optional(number)
  }))
  default = {}
}
