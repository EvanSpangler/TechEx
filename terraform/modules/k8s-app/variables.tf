variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "tasky"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "tasky"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 2
}

variable "mongodb_uri" {
  description = "MongoDB connection URI"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
  default     = "wiz-exercise-jwt-secret-2024"
}
