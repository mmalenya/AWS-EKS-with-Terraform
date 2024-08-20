variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Target AWS region"
}

variable "cluster_name" {
  type        = string
  default     = "demo-cluster"
  description = "Name of the EKS cluster"
}


variable "global_tags" {
  type = map(string)
  default = {
    "ManagedBy"   = "Terraform"
    "Environment" = "dev"
  }
}