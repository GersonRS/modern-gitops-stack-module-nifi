resource "null_resource" "dependencies" {
  triggers = var.dependency_ids
}

resource "argocd_project" "this" {
  count = var.argocd_project == null ? 1 : 0

  metadata {
    name      = var.destination_cluster != "in-cluster" ? "nifi-${var.destination_cluster}" : "nifi"
    namespace = "argocd"
    annotations = {
      "modern-gitops-stack.io/argocd_namespace" = "argocd"
    }
  }

  spec {
    description  = "nifi application project for cluster ${var.destination_cluster}"
    source_repos = ["https://github.com/GersonRS/modern-gitops-stack-module-nifi.git"]


    destination {
      name      = var.destination_cluster
      namespace = "nifi"
    }

    orphaned_resources {
      warn = true
    }

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}

data "utils_deep_merge_yaml" "values" {
  input = [for i in concat(local.helm_values, var.helm_values) : yamlencode(i)]
}

data "utils_deep_merge_yaml" "nifikop" {
  input = [for i in local.helm_nifikop : yamlencode(i)]
}

resource "argocd_application" "crds" {
  metadata {
    name      = "nifikop-crds"
    namespace = "argocd"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = "https://github.com/GersonRS/modern-gitops-stack-module-nifi.git"
      path            = "charts/nifikop/crds"
      target_revision = var.target_revision
    }

    destination {
      name      = "in-cluster"
      namespace = "nifi"
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }
    }
  }
  depends_on = [
    resource.null_resource.dependencies,
  ]
}


resource "argocd_application" "nifikop" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "nifikop-${var.destination_cluster}" : "nifikop"
    namespace = "argocd"
    labels = merge({
      "application" = "nifikop"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = "https://github.com/GersonRS/modern-gitops-stack-module-nifi.git"
      path            = "charts/nifikop"
      target_revision = var.target_revision
      helm {
        release_name = "nifikop"
        skip_crds    = true
        values       = data.utils_deep_merge_yaml.nifikop.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = "nifi"
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }
      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }
  depends_on = [
    resource.argocd_application.crds,
  ]
}

resource "argocd_application" "this" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "nifi-${var.destination_cluster}" : "nifi"
    namespace = "argocd"
    labels = merge({
      "application" = "nifi"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = "https://github.com/GersonRS/modern-gitops-stack-module-nifi.git"
      path            = "charts/nifi"
      target_revision = var.target_revision
      helm {
        release_name = "nifi"
        values       = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = "nifi"
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }

      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }
  depends_on = [
    resource.argocd_application.nifikop,
  ]
}

resource "null_resource" "this" {
  depends_on = [
    resource.argocd_application.this,
  ]
}
