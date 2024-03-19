variable "secret_name" {
  type        = string
}

variable "environment" {}

variable "secret_map" {
  default = {
    key1 = "value1"
    key2 = "value2"
  }

  type = map(string)
  sensitive = true
}
