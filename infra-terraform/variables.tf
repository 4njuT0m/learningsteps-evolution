variable "prefix" {
  description = "Short name used in all resource names"
  type        = string
  default     = "lsevo"
}

variable "location" {
  description = "Azure region for all project resources"
  type        = string
  default     = "westeurope"
}

variable "operator_ip" {
  description = "My public IPv4 address. Only this address may reach the AKS API server and the Key Vault from outside Azure."
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", var.operator_ip))
    error_message = "operator_ip must be a single IPv4 address, for example 203.0.113.10."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for AKS"
  type        = string
  default     = "1.36"
}

variable "node_vm_size" {
  description = "VM size of the AKS nodes"
  type        = string
  default     = "Standard_D2s_v6"
}

variable "node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 2
}

variable "postgres_sku" {
  description = "Size of the PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "lsevo"
}

variable "api_service_account" {
  description = "Kubernetes service account used by the API pods"
  type        = string
  default     = "lsevo-api"
}

variable "dbinit_service_account" {
  description = "Kubernetes service account used by the one-time database setup job"
  type        = string
  default     = "lsevo-dbinit"
}
