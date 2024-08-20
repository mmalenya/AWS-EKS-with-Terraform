variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "enabled_cluster_log_types" {
  description = "List of strings specifying cluster log types"
  type        = list(string)
  default     = ["audit", "api", "authenticator"]
}

variable "private_subnets" {
  description = "Private Subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public Subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "managed_node_groups" {
  description = "Map of maps specifying managed node groups"
  type = map(object({
    name : string
    desired_size : number
    min_size : number
    max_size : number
    instance_types : list(string)
  }))
  default = {}
}

variable "cluster_addons" {
  description = "List of strings specifying cluster addons"
  type        = list(string)
  default     = ["vpc-cni", "kube-proxy", "coredns", "aws-ebs-csi-driver"]
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}
