
locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.istio_service_mesh_primary_1.endpoint}
    certificate-authority-data: ${aws_eks_cluster.istio_service_mesh_primary_1.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "istio-service-mesh-primary-1"
        - "-r"
        - "arn:aws:iam::<aws-account-id>:role/<your-iam-role>"
KUBECONFIG

  kubeconfig_2 = <<KUBECONFIG_2
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.istio_service_mesh_primary_2.endpoint}
    certificate-authority-data: ${aws_eks_cluster.istio_service_mesh_primary_2.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "istio-service-mesh-primary-2"
        - "-r"
        - "arn:aws:iam::<aws-account-id>:role/<your-iam-role>"
KUBECONFIG_2
}

output "kubeconfig_cluster1" {
  value = local.kubeconfig
}

output "kubeconfig_cluster2" {
  value = local.kubeconfig_2
}

output "cluster_name" {
  value = aws_eks_cluster.istio_service_mesh_primary_1.name
}

output "cluster_name_2" {
  value = aws_eks_cluster.istio_service_mesh_primary_2.name
}