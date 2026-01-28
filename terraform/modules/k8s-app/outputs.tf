output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "service_account_name" {
  description = "ServiceAccount name"
  value       = kubernetes_service_account.app.metadata[0].name
}

output "service_name" {
  description = "Kubernetes service name"
  value       = kubernetes_service.app.metadata[0].name
}

output "ingress_name" {
  description = "Ingress name"
  value       = kubernetes_ingress_v1.app.metadata[0].name
}
