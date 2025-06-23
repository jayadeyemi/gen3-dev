data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}