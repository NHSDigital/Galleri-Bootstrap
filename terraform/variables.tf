variable "bucket_name" {
  type    = string
  default = "galleri-lambda-bucket"
}
variable "role_name" {
  type    = string
  default = "galleri-lambda-role"
}

variable "environment" {
  description = "The environment being deployed into, could be: dev, test, uat, performance or prod"
}

variable "account_id" {
  
}
