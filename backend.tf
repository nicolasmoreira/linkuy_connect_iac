terraform {
  backend "s3" {
    bucket  = "linkuyconnect-terraform-state"
    key     = "terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}
