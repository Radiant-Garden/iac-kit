# tofu test for the catalog module, run from tofu/modules/catalog.
#
# "valid" compares every output with examples/catalog/expected.json, which was
# written by hand, not generated. jsonencode() on both sides compares values
# and ignores list/tuple and map/object type differences.
#
# Every catalog in examples/catalog/invalid/ has a run below that expects the
# output named in its "# expect-output:" header to fail the plan.
# ci/check-invalid-examples.sh checks the message and that this list is
# complete.

run "valid" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/catalog.yml"))
  }

  assert {
    condition     = jsonencode(output.site) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).site)
    error_message = "output.site differs from expected.json: ${jsonencode(output.site)}"
  }
  assert {
    condition     = jsonencode(output.apps) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).apps)
    error_message = "output.apps differs from expected.json: ${jsonencode(output.apps)}"
  }
  assert {
    condition     = jsonencode(output.instances) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).instances)
    error_message = "output.instances differs from expected.json: ${jsonencode(output.instances)}"
  }
  assert {
    condition     = jsonencode(output.service_names) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).service_names)
    error_message = "output.service_names differs from expected.json: ${jsonencode(output.service_names)}"
  }
  assert {
    condition     = jsonencode(output.acme_names) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).acme_names)
    error_message = "output.acme_names differs from expected.json: ${jsonencode(output.acme_names)}"
  }
  assert {
    condition     = jsonencode(output.policies) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).policies)
    error_message = "output.policies differs from expected.json: ${jsonencode(output.policies)}"
  }
  assert {
    condition     = jsonencode(output.guests) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).guests)
    error_message = "output.guests differs from expected.json: ${jsonencode(output.guests)}"
  }
  assert {
    condition     = jsonencode(output.sign_in) == jsonencode(jsondecode(file("../../../examples/catalog/expected.json")).sign_in)
    error_message = "output.sign_in differs from expected.json: ${jsonencode(output.sign_in)}"
  }
}

run "invalid_access_empty" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/access-empty.yml"))
  }

  expect_failures = [output.apps]
}

run "invalid_alias_duplicate" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/alias-duplicate.yml"))
  }

  expect_failures = [output.service_names]
}

run "invalid_alias_is_instance" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/alias-is-instance.yml"))
  }

  expect_failures = [output.service_names]
}

run "invalid_alias_target" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/alias-target.yml"))
  }

  expect_failures = [output.service_names]
}

run "invalid_compose_project_duplicate" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/compose-project-duplicate.yml"))
  }

  expect_failures = [output.instances]
}

run "invalid_environments_empty" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/environments-empty.yml"))
  }

  expect_failures = [output.site]
}

run "invalid_guest_host_fields" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/guest-host-fields.yml"))
  }

  expect_failures = [output.instances]
}

run "invalid_guest_ip" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/guest-ip.yml"))
  }

  expect_failures = [output.guests]
}

run "invalid_host_and_guest" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/host-and-guest.yml"))
  }

  expect_failures = [output.instances]
}

run "invalid_instance_duplicate" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/instance-duplicate.yml"))
  }

  expect_failures = [output.instances]
}

run "invalid_instance_name" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/instance-name.yml"))
  }

  expect_failures = [output.instances]
}

run "invalid_ip_duplicate" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/ip-duplicate.yml"))
  }

  expect_failures = [output.guests]
}

run "invalid_label_length" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/label-length.yml"))
  }

  expect_failures = [output.service_names]
}

run "invalid_missing_key" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/missing-key.yml"))
  }

  expect_failures = [output.site]
}

run "invalid_port_range" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/port-range.yml"))
  }

  expect_failures = [output.apps]
}

run "invalid_schema_version" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/schema-version.yml"))
  }

  expect_failures = [output.site]
}

run "invalid_sign_in_duplicate" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/sign-in-duplicate.yml"))
  }

  expect_failures = [output.sign_in]
}

run "invalid_unknown_key" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/unknown-key.yml"))
  }

  expect_failures = [output.site]
}

run "invalid_upstream_format" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/upstream-format.yml"))
  }

  expect_failures = [output.instances]
}

run "invalid_vm_id_duplicate" {
  command = plan

  variables {
    catalog = yamldecode(file("../../../examples/catalog/invalid/vm-id-duplicate.yml"))
  }

  expect_failures = [output.guests]
}
