variable "project_id" {
  type    = string
  default = "globalconnect-dev"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "source_image" {
  type    = string
  default = "ubuntu-2204-jammy-v20230630"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}
