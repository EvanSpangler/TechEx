variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_guardduty" {
  description = "Enable GuardDuty (set to false if already enabled in account)"
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "Enable AWS Config (set to false if already enabled in account)"
  type        = bool
  default     = false
}
