resource "aws_iam_role" "eks_iam_role" {
  name = "AmazonAwsEksRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  tags = local.default_tags
}

resource "aws_iam_policy_attachment" "eksClusterPolicyAttachmentDefault" {
  name       = "eksClusterPolicyAttachmentDefault"
  roles      = [aws_iam_role.eks_iam_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_iam_node_role" {
  name = "AmazonAwsEksNodeRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
  depends_on = [
    aws_iam_role.eks_iam_role,
    aws_iam_policy_attachment.eksClusterPolicyAttachmentDefault
  ]
}
resource "aws_iam_policy_attachment" "AmazonEKSWorkerNodePolicyAttachment" {
  name       = "AmazonEKSWorkerNodePolicyAttachment"
  roles      = [aws_iam_role.eks_iam_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_policy_attachment" "AmazonEC2ContainerRegistryReadOnlyAttachment" {
  name       = "AmazonEC2ContainerRegistryReadOnlyAttachment"
  roles      = [aws_iam_role.eks_iam_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_policy_attachment" "AmazonEKSCNIPolicyAttachment" {
  name       = "AmazonEKSCNIPolicyAttachment"
  roles      = [aws_iam_role.eks_iam_node_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

