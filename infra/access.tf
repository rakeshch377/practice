################################################################################
# IAM Role: assumable by trusted users to get EKS cluster access
################################################################################

resource "aws_iam_role" "cluster_admins" {
  name = "${var.cluster_name}-cluster-admins"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.cluster_admin_user_arns
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM permission to call the EKS API (needed for `update-kubeconfig` and
# kubectl auth). Separate from the access entry below, which controls
# what the role can do *inside* the cluster via Kubernetes RBAC.
resource "aws_iam_role_policy" "cluster_admins_eks_api" {
  name = "${var.cluster_name}-eks-api-access"
  role = aws_iam_role.cluster_admins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = module.eks.cluster_arn
    }]
  })
}

################################################################################
# EKS Access Entry: lets the role above talk to the cluster
################################################################################

resource "aws_eks_access_entry" "cluster_admins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.cluster_admins.arn
}

resource "aws_eks_access_policy_association" "cluster_admins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.cluster_admins.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admins]
}

