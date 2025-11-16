terraform {
  backend "s3" {
    bucket         = "softbank2025-cat-tfstate"
    key            = "cat-cicd/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "softbank2025-cat-tfstate-lock"
    encrypt        = true
  }
}
