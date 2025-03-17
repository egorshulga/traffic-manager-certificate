terraform {
  required_version = ">= 1.11.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.22.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.1"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscriptionId

  resource_provider_registrations = "none"

  features {}
}
