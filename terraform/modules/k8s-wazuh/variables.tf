variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Wazuh agent"
  type        = string
  default     = "wazuh"
}

variable "wazuh_manager_ip" {
  description = "Wazuh Manager private IP address"
  type        = string
}

variable "wazuh_agent_version" {
  description = "Wazuh agent version"
  type        = string
  default     = "4.14.2"
}

variable "wazuh_cluster_name" {
  description = "Name identifier for this Kubernetes cluster in Wazuh"
  type        = string
  default     = ""
}
