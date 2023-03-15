################################################################################
# Sysdig specific parameters
################################################################################

variable "sysdig_access_key" {
  description = "Sysdig Agent Token"
  type        = string
}

variable "sysdig_secure_api_token" {
  description = "Sysdig API Token"
  type        = string
}

variable "sysdig_collector_url" {
  description = "Sysdig Collector Url"
  type        = string
}
