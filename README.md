# terraform-aws-docdb-cluster-parameter-group

Terraform module for an Amazon DocumentDB cluster parameter group — the
engine configuration applied to every instance in the clusters that
reference it.

## Cost

Cluster parameter groups carry no charge. This module has no cost impact
of its own. A parameter it sets may have one: enabling `audit_logs` or
`profiler` sends records to CloudWatch Logs, which bills at standard
CloudWatch Logs rates. See AWS's
[CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) page
for current rates.

## Design

This is the DocumentDB counterpart to
[`terraform-aws-db-parameter-group`](https://github.com/kn47ytv9mv/terraform-aws-db-parameter-group),
and the two take the same shape deliberately. What differs is DocumentDB
itself, in three ways that matter to a caller.

`family` is DocumentDB-specific and takes a `docdb` form, not the
`postgres17` or `mysql8.0` form the RDS module uses. The families AWS
documents are `docdb4.0`, `docdb5.0`, and `docdb8.0`; `docdb3.6` reached
end of life in March 2026 and is available only under paid Extended
Support. `family` must match the major engine version of every cluster
using this group, and it is immutable — changing it destroys the group
and creates a replacement, which means every cluster pointing at it must
be moved in the same operation.

DocumentDB accepts a small, fixed set of cluster parameters rather than
the hundreds an RDS engine exposes, and a caller cannot discover them
from this module or from the provider schema. The ones worth knowing:

| Parameter | Default | Valid values |
|---|---|---|
| `audit_logs` | `none` | `ddl`, `dml_read`, `dml_write`, `all`, `none`, and the legacy `enabled` and `disabled` |
| `tls` | `enabled` | `enabled`, `disabled`, `fips-140-3`, `tls1.2+`, `tls1.3+` |
| `ttl_monitor` | `enabled` | `enabled`, `disabled` |
| `profiler` | `disabled` | `enabled`, `disabled` |
| `profiler_threshold_ms` | `100` | `50` to `2147483646` |
| `profiler_sampling_rate` | `1.0` | `0.0` to `1.0` |
| `change_stream_log_retention_duration` | `10800` | `3600` to `604800` |

`audit_logs` accepts a comma-delimited combination of its event
categories, so `ddl,dml_write` is valid. The `enabled` and `disabled`
values are legacy aliases for `ddl` and `none` respectively, and AWS
recommends against using them.

`apply_method` is `'immediate'` or `'pending-reboot'`, and DocumentDB is
specific about which applies. Every parameter above is dynamic except
`tls`, which is static: a change to `tls` takes effect only after each
instance in the cluster is rebooted, so pair it with
`apply_method = 'pending-reboot'` and expect to reboot deliberately
rather than waiting for the change to land on its own.

### Transport Layer Security

`tls` defaults to `enabled` on AWS's own default parameter group, and
setting it to `disabled` removes the requirement that clients connect
over TLS. That is a security decision with consequences beyond this
module: traffic between application and database becomes readable on the
network, and a cluster that has accepted plaintext connections cannot
retroactively secure the sessions that already happened. Prefer
`tls1.2+` or `tls1.3+` to raise the floor instead, or `fips-140-3` where
a Federal Information Processing Standards posture is required. If
`disabled` is genuinely needed — a legacy driver that cannot negotiate
TLS at all — treat it as a temporary state with a migration behind it,
not as a configuration setting.

### Audit logging requires the cluster to cooperate

Setting `audit_logs` is only half of enabling auditing. The cluster
itself must also export the `audit` log type to CloudWatch Logs through
`enabled_cloudwatch_logs_exports`, which is a property of the cluster and
not of this group. Setting the parameter without the export produces
nothing at all: no error, no warning, and no log stream — the parameter
reads as enabled while auditing is silently inert. The export side
belongs to [`terraform-aws-docdb-cluster`](https://github.com/kn47ytv9mv/terraform-aws-docdb-cluster); the Usage section below shows
both halves together, because either one alone is a no-op.

### Ordering and reassignment

A cluster parameter group must exist before the cluster that references
it, and Terraform infers that ordering automatically from the reference
in the cluster's `db_cluster_parameter_group_name`. Reassignment is the
part worth planning for: moving an existing cluster from one group to
another, or changing a static parameter inside the group it already uses,
requires rebooting each instance before the new configuration takes
effect. AWS also asks for a five-minute wait after a group is created
before a cluster is pointed at it.

### Naming

A generated name is prefixed (`pg-`) because AWS requires a cluster
parameter group name to begin with a letter, and a bare UUID may begin
with a digit. An explicitly supplied `name` is validated against the same
rule, along with AWS's prohibitions on a trailing hyphen and on two
consecutive hyphens, so the failure arrives at plan time with a clear
message rather than from the provider mid-apply.

### Deliberately not covered

`name_prefix` is not exposed: it is mutually exclusive with `name`, and
this module already generates a unique name when `name` is unset.
DocumentDB has no instance-level parameter group and no equivalent of
`aws_db_parameter_group`'s `skip_destroy`, so neither appears here.

## Usage

```hcl
module "parameter_group" {
  source = "kn47ytv9mv/docdb-cluster-parameter-group/aws"

  family = "docdb5.0"

  parameters = [
    { name = "audit_logs", value = "all" },
  ]
}

module "cluster" {
  source = "kn47ytv9mv/docdb-cluster/aws"

  master_username = "app"

  db_cluster_parameter_group_name = module.parameter_group.name
  enabled_cloudwatch_logs_exports = ["audit"]
}
```

Or directly from this repository, raising the TLS floor and turning on
the profiler for slow operations:

```hcl
module "parameter_group" {
  source = "github.com/kn47ytv9mv/terraform-aws-docdb-cluster-parameter-group"

  name   = "production-docdb5"
  family = "docdb5.0"

  parameters = [
    { name = "tls", value = "tls1.2+", apply_method = "pending-reboot" },
    { name = "profiler", value = "enabled" },
    { name = "profiler_threshold_ms", value = "500" },
    { name = "ttl_monitor", value = "enabled" },
  ]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the cluster parameter group. Must begin with a letter, must not end with a hyphen, and must not contain two consecutive hyphens. If null, a unique name is generated. | `null` | no |
| description | Description of the cluster parameter group. If null, AWS's own default applies. | `null` | no |
| family | The DocumentDB engine family these parameters apply to (`'docdb4.0'`, `'docdb5.0'`, or `'docdb8.0'`). Must match the major engine version of every cluster using this group, and cannot be changed without replacing the group. | `null` | no |
| parameters | Parameters to set, each with a `name` and `value`. DocumentDB accepts a small fixed set of cluster parameters rather than the hundreds an RDS engine exposes; the Design section lists the ones worth knowing and their valid values. `apply_method` is `'immediate'` or `'pending-reboot'` — `tls` is a static parameter and only takes effect after a reboot. | `[]` | no |
| tags | A map of tags to assign to the cluster parameter group. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID (name) of the cluster parameter group. |
| arn | The ARN of the cluster parameter group. |
| name | The name of the cluster parameter group. Feed this into the cluster's `db_cluster_parameter_group_name`, which identifies the group by name rather than by ARN. |

## License

MIT — see [LICENSE.md](LICENSE.md).
