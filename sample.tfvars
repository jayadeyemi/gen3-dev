aws_profile               = "boadeyem_tf"
region                    = "us-east-1"
vpc_name                  = "gen3-vpc"
vpc_cidr                  = "10.0.0.0/16"
vpc_private_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
vpc_public_subnets        = ["10.0.101.0/24", "10.0.102.0/24"]
eks_cluster_name          = "gen3-eks-cluster"
eks_cluster_random_suffix = "" # Optional: Add a random suffix to the cluster name
cluster_user_ips          = [""] # Optional: Add IPs for cluster user access
helm_services             = [
  {
    name = "s3"
    version = "1.0.33"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  }
]
