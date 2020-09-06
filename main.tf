provider "aws" {
  region = "eu-west-1"
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

module "web_stack" {
  source = "../terraform-aws-asg-alb/"

  vpc_id                                        = var.vpc_id
  name                                          = "${var.env}-${var.service}-tiendeo"
  create_external_load_balancer                 = true
  lb_subnet_ids                                 = var.public_subnet_ids
  lb_health_check_port                          = "5106"
  lb_health_check_path                          = "/"
  lb_external_security_group_ids                = [module.lb_sg.this_security_group_id]
  lb_target_group_port                          = 5106
  lb_listener_port_external                     = 80
  lb_listener_protocol_external                 = "HTTP"
  launch_template_image_id                      = data.aws_ami.amazon-linux-2.id
  launch_template_instance_type                 = "t3.small"
  launch_template_key_name                      = "pro-tiendeo"
  launch_template_user_data                     = "${file("resources/userdata_${var.env}.sh")}"
  launch_template_root_block_device_volume_size = 20
  launch_template_security_groups               = [module.ec2_sg.this_security_group_id]
  launch_template_ebs_optimized                 = false
  launch_template_instance_profile              = aws_iam_instance_profile.tiendeo_web_ec2.name
  asg_min_size                                  = 0
  asg_max_size                                  = 1
  asg_desired_capacity                          = 1
  asg_subnet_ids                                = ["subnet-0273efd2e96e51e44", "subnet-0879801d7b3a4a158", "subnet-08c0892bf7b5f1eb6"]
  asg_health_check_type                         = "EC2"

  tags = merge({
    Name    = "${var.env}-${var.service}-tiendeo",
    service = "web"
  }, var.tags)
}

module "lb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.0.1"

  name            = "${var.env}-${var.service}-tiendeo-lb-sg"
  use_name_prefix = true
  vpc_id          = var.vpc_id

  egress_rules = ["all-all"]

  ingress_with_cidr_blocks = [
    {
      rule        = "http-80-tcp"
      description = "Access from anywhere"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = merge({
    Name    = "${var.env}-${var.service}-tiendeo-lb-sg",
    service = var.service
  }, var.tags)
}

module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.0.1"

  name            = "${var.env}-${var.service}-tiendeo-ec2-sg"
  use_name_prefix = true
  vpc_id          = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 5106
      to_port                  = 5106
      protocol                 = "tcp"
      source_security_group_id = module.lb_sg.this_security_group_id
    }
  ]

  egress_rules = ["all-all"]
  tags = merge({
    Name    = "${var.env}-${var.service}-tiendeo-lb-sg",
    service = var.service
  }, var.tags)
}

# Instance roles 
resource "aws_iam_role" "tiendeo_web_ec2" {
  name               = "${var.env}-${var.service}-tiendeo-ec2-role"
  assume_role_policy = file("policies/ec2_trust_relationship.json")

  tags = merge({
    Name    = "${var.env}-${var.service}-tiendeo-lb-sg",
    service = var.service
  }, var.tags)
}

resource "aws_iam_instance_profile" "tiendeo_web_ec2" {
  name = "${var.env}-${var.service}-tiendeo-ec2-iprofile"
  role = aws_iam_role.tiendeo_web_ec2.name
}

resource "aws_iam_role_policy" "tiendeo_web_ec2_policy" {
  name = "${var.env}-${var.service}-tiendeo-ec2-policy"
  role = aws_iam_role.tiendeo_web_ec2.name
  policy = file("policies/ec2_role.json")
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.tiendeo_web_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# CodeDeploy
resource "aws_codedeploy_app" "tiendeo_dotnet_app" {
  name = "${var.env}-${var.service}-tiendeo-app"
}

resource "aws_iam_role" "tiendeo_dotnet_codedeploy" {
  name               = "${var.env}-${var.service}-tiendeo-codedeploy"
  assume_role_policy = file("policies/codedeploy_trust_relationship.json")
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.tiendeo_dotnet_codedeploy.name
}

resource "aws_iam_policy" "ec2_policy" {
  name        = "${var.env}-${var.service}-tiendeo-ec2-policy"
  path        = "/"
  description = "S3 access for codedeploy"

  policy = file("policies/ec2_role.json")
}


resource "aws_codedeploy_deployment_group" "tiendeo_dotnet_deployment_group" {
  app_name              = aws_codedeploy_app.tiendeo_dotnet_app.name
  deployment_group_name = "${var.env}-${var.service}-tiendeo"
  service_role_arn      = aws_iam_role.tiendeo_dotnet_codedeploy.arn

  autoscaling_groups = [module.web_stack.autoscaling_group.id]
}
