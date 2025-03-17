# Step 1 - provisioning of Traffic Manager.

resource "random_uuid" "trafficManager" {} # For unique DNS name.

resource "azurerm_traffic_manager_profile" "trafficManager" {
  name                = "traffic-manager"
  resource_group_name = azurerm_resource_group.resourceGroup.name

  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "tm-${random_uuid.trafficManager.result}"
    ttl           = 30 # seconds
  }

  monitor_config {
    protocol = "HTTPS"
    port     = 443
    path     = "/ping"
  }
}

# Step 2 - provisioning of Endpoint. It also creates necessary whitelisting.

data "azurerm_subscription" "subscription" {}

locals {
  ipsToWhitelist = ["216.168.247.9", "216.168.249.9"]
}

resource "azurerm_traffic_manager_azure_endpoint" "backend" {
  name               = azurerm_linux_web_app.appService.name
  profile_id         = azurerm_traffic_manager_profile.trafficManager.id
  target_resource_id = azurerm_linux_web_app.appService.id
  weight             = 1

  # Adding whitelisting - so it will be ready _before_ provisioning of certificate (below).
  provisioner "local-exec" {
    when        = create
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $ipsToWhitelist = $env:ipsToWhitelist | ConvertFrom-Json
      foreach ($ip in $ipsToWhitelist) {
        az webapp config access-restriction add `
          --subscription $env:subscription `
          --resource-group $env:resourceGroup `
          --name $env:appService `
          --rule-name $ip `
          --priority 100 `
          --ip-address $ip `
          --action Allow
        if ($LASTEXITCODE -ne 0) {
          exit $LASTEXITCODE
        }
      }
    EOT
    environment = {
      subscription   = data.azurerm_subscription.subscription.subscription_id
      resourceGroup  = azurerm_linux_web_app.appService.resource_group_name
      appService     = azurerm_linux_web_app.appService.name
      ipsToWhitelist = jsonencode(local.ipsToWhitelist)
    }
    quiet = true
  }
}

# Step 3: provisioning of certificate.

resource "azurerm_app_service_managed_certificate" "certificate" {
  depends_on = [azurerm_traffic_manager_azure_endpoint.backend]
  # Custom Hostname is created automatically when a Traffic Manager Endpoint is created.
  custom_hostname_binding_id = "${azurerm_linux_web_app.appService.id}/hostNameBindings/${azurerm_traffic_manager_profile.trafficManager.fqdn}"

  # After certificate is provisioned successfully - removing the IPs (which were provisioned above).
  provisioner "local-exec" {
    when        = create
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $ipsToWhitelist = $env:ipsToWhitelist | ConvertFrom-Json
      foreach ($ip in $ipsToWhitelist) {
        az webapp config access-restriction remove `
          --subscription $env:subscription `
          --resource-group $env:resourceGroup `
          --name $env:appService `
          --rule-name $ip
        if ($LASTEXITCODE -ne 0) {
          exit $LASTEXITCODE
        }
      }
    EOT
    environment = {
      subscription   = data.azurerm_subscription.subscription.subscription_id
      resourceGroup  = azurerm_linux_web_app.appService.resource_group_name
      appService     = azurerm_linux_web_app.appService.name
      ipsToWhitelist = jsonencode(local.ipsToWhitelist)
    }
    quiet = true
  }
}

# Step 4: binding the provisioned certificate.

resource "azurerm_app_service_certificate_binding" "bindingCertificateToDomain" {
  hostname_binding_id = "${azurerm_linux_web_app.appService.id}/hostNameBindings/${azurerm_traffic_manager_profile.trafficManager.fqdn}"
  certificate_id      = azurerm_app_service_managed_certificate.certificate.id
  ssl_state           = "SniEnabled"
}
