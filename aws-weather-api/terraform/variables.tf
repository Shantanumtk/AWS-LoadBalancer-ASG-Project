variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for the ASG"
}

# If you have an existing EC2 key pair, set its name here (e.g., wl-kp).
# Leave empty to omit a key pair (use SSM Session Manager instead).
variable "key_name" {
  type        = string
  default     = "my-key-pair-2"
  description = "Existing EC2 key pair name (optional)."
}
