# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              PLAN-TIME CHECKS                                ║
# ║                                                                              ║
# ║  Warnings for legal but risky configurations. They never block the plan.     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

check "acl_wide_ranges" {
  assert {
    condition = var.allow_public_access || alltrue([
      for rule in var.acl_rules :
      rule.ip == "0.0.0.0/0" || tonumber(split("/", rule.ip)[1]) >= 8
    ])
    error_message = "An ACL rule covers a very wide range (prefix shorter than /8, such as 0.0.0.0/1). Restrict it, or set allow_public_access = true to acknowledge it."
  }
}

check "manual_backup_volume_size" {
  assert {
    condition = length(var.manual_backups) == 0 || (
      var.volume_size_in_gb == null || var.volume_size_in_gb <= 585
    )
    error_message = "Manual backups are only available for instances with storage up to 585 GB; volume_size_in_gb is larger."
  }
}
