variable "region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Instance type for the EC2 signaling server"
  default     = "t2.micro"
}
