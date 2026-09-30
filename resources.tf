resource "random_uuid" "resource" {}

resource "aws_docdb_cluster_parameter_group" "resource" {
  name        = coalesce(var.name, "pg-${random_uuid.resource.id}")
  description = var.description
  family      = var.family

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = var.tags
}

output "id" {
  description = "The ID (name) of the cluster parameter group."
  value       = aws_docdb_cluster_parameter_group.resource.id
}

output "arn" {
  description = "The ARN of the cluster parameter group."
  value       = aws_docdb_cluster_parameter_group.resource.arn
}

output "name" {
  description = "The name of the cluster parameter group. Feed this into the cluster's db_cluster_parameter_group_name, which identifies the group by name rather than by ARN."
  value       = aws_docdb_cluster_parameter_group.resource.name
}
