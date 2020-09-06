variable "env" {
  type    = string
  default = "pro"
}

variable "service" {
  type    = string
  default = "web"
}

variable "tags" {
  type = map
  default = {
    env   = "pro"
    owner = "tiendeo"
  }
}

variable "vpc_id" {
  type    = string
  default = "vpc-0a6b732d5d5ab278f"
}

variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-00706525752543cb0", "subnet-0c37761274a64cc05", "subnet-06fd4f692fb95304e"]
}

variable "private_subnet_ids" {
  type    = list(string)
  default = ["subnet-0273efd2e96e51e44", "subnet-0879801d7b3a4a158", "subnet-08c0892bf7b5f1eb6"]
}

