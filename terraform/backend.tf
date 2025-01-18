terraform {
  backend "s3" {
    bucket         = "terraform-state-storage-shaan"
    key            = "file-sharing-webapp/terraform.tfstate"
    region         = "us-east-1"
  }
}
