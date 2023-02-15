resource "helm_release" "csi" {
  name       = "csi"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.1.2"
  namespace  = "vault"
  create_namespace = true
  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
  depends_on = [helm_release.argocd]
}
