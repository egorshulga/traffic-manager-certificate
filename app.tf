resource "azurerm_resource_group" "resourceGroup" {
  name     = "test"
  location = "westeurope"
}

resource "azurerm_service_plan" "appServicePlan" {
  name                = "app-service-plan"
  resource_group_name = azurerm_resource_group.resourceGroup.name
  location            = azurerm_resource_group.resourceGroup.location

  os_type  = "Linux"
  sku_name = "P1v2"
}

resource "random_uuid" "appService" {} # For unique name.

resource "azurerm_linux_web_app" "appService" {
  name                = "app-service-${random_uuid.appService.result}"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  service_plan_id     = azurerm_service_plan.appServicePlan.id

  https_only = true

  site_config {
    ip_restriction_default_action = "Deny"
  }
}
