resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.19.0"
  namespace  = "vault"
  values = [
    file("files/vault-values.yaml")
  ]
  set {
    name  = "csi.enabled"
    value = "true"
  }
  set {
    name  = "injector.enabled"
    value = "false"
  }
  depends_on = [helm_release.csi]
}

resource "null_resource" "wait_for_vault" {
  triggers = {
    key = uuid()
  }
  provisioner "local-exec" {
    command = "bash vault.sh"
  }

  depends_on = [helm_release.vault]
}
