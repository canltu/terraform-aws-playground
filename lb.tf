module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name = "elb-andrius"

  subnets         = [aws_subnet.andrius.id]
  security_groups = [aws_security_group.andrius.id]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    }
  ]

  health_check = {
    target              = "HTTP:80/healthz"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  // access_logs = {
  //  bucket = "my-access-logs-bucket"
  // }

  // ELB attachments
  number_of_instances = 1
  instances           = [aws_instance.andrius.id]

  tags = {
    Purpose     = "Signining"
    Environment = "prod"
  }
}
