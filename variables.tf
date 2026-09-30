variable "name" {
  default     = null
  description = "Name of the cluster parameter group. Must begin with a letter, must not end with a hyphen, and must not contain two consecutive hyphens. If null, a unique name is generated."

  validation {
    condition     = var.name == null || can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,254}$", var.name))
    error_message = "A cluster parameter group's name must begin with a letter and may contain only letters, digits, and hyphens, up to 255 characters."
  }

  validation {
    condition     = var.name == null || !can(regex("(--|-$)", var.name))
    error_message = "A cluster parameter group's name must not end with a hyphen or contain two consecutive hyphens."
  }
}

variable "description" {
  default     = null
  description = "Description of the cluster parameter group. If null, AWS's own default applies."
}

variable "family" {
  default     = null
  description = "The DocumentDB engine family these parameters apply to ('docdb4.0', 'docdb5.0', or 'docdb8.0'). Must match the major engine version of every cluster using this group, and cannot be changed without replacing the group."

  validation {
    condition     = var.family == null || can(regex("^docdb", var.family))
    error_message = "A DocumentDB cluster parameter group family begins with 'docdb'. An RDS family such as 'postgres17' belongs to terraform-aws-db-parameter-group instead."
  }
}

variable "parameters" {
  default     = []
  description = "Parameters to set, each with a name and value. DocumentDB accepts a small fixed set of cluster parameters rather than the hundreds an RDS engine exposes; the README's Design section lists the ones worth knowing and their valid values. apply_method is 'immediate' or 'pending-reboot' — 'tls' is a static parameter and only takes effect after a reboot."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string)
  }))

  validation {
    condition     = alltrue([for p in var.parameters : p.apply_method == null || contains(["immediate", "pending-reboot"], p.apply_method)])
    error_message = "A parameter's apply_method must be either 'immediate' or 'pending-reboot'."
  }
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the cluster parameter group."
}
