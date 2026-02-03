output "namespace" {
  description = "Kubernetes namespace where Wazuh agent is deployed"
  value       = kubernetes_namespace.wazuh.metadata[0].name
}

output "daemonset_name" {
  description = "Name of the Wazuh agent DaemonSet"
  value       = kubernetes_daemonset.wazuh_agent.metadata[0].name
}

output "service_account_name" {
  description = "Name of the Wazuh agent ServiceAccount"
  value       = kubernetes_service_account.wazuh_agent.metadata[0].name
}
