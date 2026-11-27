# Example root: reads a catalog and exposes the whole model as
# `output "catalog"`, which Ansible reads with `tofu output -json catalog`.
#
#   tofu init && tofu plan
#   tofu plan -var catalog_file=invalid/alias-target.yml   # fails, see invalid/

variable "catalog_file" {
  description = "Catalog to read, relative to this directory."
  type        = string
  default     = "catalog.yml"
}

module "catalog" {
  source  = "../../tofu/modules/catalog"
  catalog = yamldecode(file("${path.module}/${var.catalog_file}"))
}

output "catalog" {
  value = {
    site          = module.catalog.site
    apps          = module.catalog.apps
    instances     = module.catalog.instances
    service_names = module.catalog.service_names
    acme_names    = module.catalog.acme_names
    policies      = module.catalog.policies
    guests        = module.catalog.guests
    sign_in       = module.catalog.sign_in
  }
}
