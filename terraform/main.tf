terraform {
  backend "s3" {
    dynamodb_table = "terraform-state-lock-dynamo"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-2"
}

module "galleri-ons-data" {
  source                  = "./modules/s3"
  bucket_name             = "galleri-ons-data"
  # galleri_lambda_role_arn = module.iam_galleri_lambda_role.galleri_lambda_role_arn
  environment             = var.environment
  account_id              = var.account_id
}

module "galleri-test-data" {
  source                  = "./modules/s3"
  bucket_name             = "galleri-test-data"
  # galleri_lambda_role_arn = module.iam_galleri_lambda_role.galleri_lambda_role_arn
  environment             = var.environment
  account_id              = var.account_id
}
