variable "catalog" {
  description = "The decoded catalog, e.g. yamldecode(file(\"catalog.yml\")). See schema/catalog.v1.schema.json."
  # `any` on purpose: an object type would silently drop unknown keys, and a
  # misspelled optional key (`upstrem:`) must fail the plan, not vanish.
  type     = any
  nullable = false
}
