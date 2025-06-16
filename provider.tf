# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
provider "aws" {
  region  = "us-east-1" # Change this to your desired AWS region
  profile = "jayadeyemi" #
}

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }
  }

  required_version = "~> 1.3"
}