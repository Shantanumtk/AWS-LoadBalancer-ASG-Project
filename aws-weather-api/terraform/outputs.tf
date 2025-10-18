output "alb_dns_name" {
  value       = aws_lb.wl.dns_name
  description = "Application Load Balancer DNS"
}

output "asg_name" {
  value       = aws_autoscaling_group.wl.name
  description = "Auto Scaling Group name"
}

output "target_group_arn" {
  value       = aws_lb_target_group.wl.arn
  description = "Target Group ARN"
}

output "vpc_id" {
  value       = aws_vpc.wl.id
  description = "VPC ID"
}
