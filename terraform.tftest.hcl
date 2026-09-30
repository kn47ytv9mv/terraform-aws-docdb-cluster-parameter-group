mock_provider "aws" {}

run "digit_leading_name_is_rejected" {
  command = plan

  variables {
    name   = "0bad-name"
    family = "docdb5.0"
  }

  expect_failures = [var.name]
}

run "double_hyphen_name_is_rejected" {
  command = plan

  variables {
    name   = "bad--name"
    family = "docdb5.0"
  }

  expect_failures = [var.name]
}

run "rds_family_is_rejected" {
  command = plan

  variables {
    family = "postgres17"
  }

  expect_failures = [var.family]
}

run "invalid_apply_method_is_rejected" {
  command = plan

  variables {
    family = "docdb5.0"
    parameters = [
      { name = "tls", value = "disabled", apply_method = "whenever" },
    ]
  }

  expect_failures = [var.parameters]
}

run "name_defaults_to_prefixed_random_uuid" {
  command = apply

  variables {
    family = "docdb5.0"
  }

  assert {
    condition     = aws_docdb_cluster_parameter_group.resource.name == "pg-${random_uuid.resource.id}"
    error_message = "Leaving name unset should fall back to a letter-prefixed random_uuid, since AWS rejects a cluster parameter group name that does not begin with a letter."
  }
}

run "no_parameters_by_default" {
  command = plan

  variables {
    family = "docdb5.0"
  }

  assert {
    condition     = length(aws_docdb_cluster_parameter_group.resource.parameter) == 0
    error_message = "Leaving parameters unset should create a group that inherits every AWS default."
  }
}

run "parameters_create_one_block_each" {
  command = plan

  variables {
    family = "docdb5.0"
    parameters = [
      { name = "audit_logs", value = "all" },
      { name = "ttl_monitor", value = "disabled" },
      { name = "profiler", value = "enabled" },
    ]
  }

  assert {
    condition     = length(aws_docdb_cluster_parameter_group.resource.parameter) == 3
    error_message = "Each entry in parameters should produce one parameter block."
  }
}

run "static_tls_parameter_carries_pending_reboot" {
  command = plan

  variables {
    family = "docdb5.0"
    parameters = [
      { name = "tls", value = "fips-140-3", apply_method = "pending-reboot" },
    ]
  }

  assert {
    condition     = one([for p in aws_docdb_cluster_parameter_group.resource.parameter : p.apply_method if p.name == "tls"]) == "pending-reboot"
    error_message = "A pending-reboot apply_method should reach the parameter block, since tls is static and cannot be applied immediately."
  }
}

run "tags_are_applied" {
  command = plan

  variables {
    family = "docdb5.0"

    tags = {
      Environment = "production"
    }
  }

  assert {
    condition     = aws_docdb_cluster_parameter_group.resource.tags["Environment"] == "production"
    error_message = "Tags should be applied to the cluster parameter group."
  }
}

run "readme_audit_logging_example" {
  command = plan

  variables {
    family = "docdb5.0"

    parameters = [
      { name = "audit_logs", value = "all" },
    ]
  }
}

run "readme_hardened_example" {
  command = plan

  variables {
    name   = "production-docdb5"
    family = "docdb5.0"

    parameters = [
      { name = "tls", value = "tls1.2+", apply_method = "pending-reboot" },
      { name = "profiler", value = "enabled" },
      { name = "profiler_threshold_ms", value = "500" },
      { name = "ttl_monitor", value = "enabled" },
    ]
  }
}
