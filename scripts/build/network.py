#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "network"
description = "Chart for Network Resources on AWS"
add_description_stub(description_overrides, controller, description)

# insert controller name into chart stub
ntwk_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
ntwk_chart_stub1 = ntwk_chart_stub1.substitute(controller=controller, descriptions=description)
add_chart_stub(chart_overrides, controller, ntwk_chart_stub1)

ntwk_values_stub1 = """vpc:
  enabled: true
  name: "Commons1"
  enabled: true
  cidrBlock: ["10.0.0.0/16"]
  tags:
    Environment: "prod"
    Organization: "MyOrg"

# flowLogs:
#   enabled: true
#   trafficType: ALL
#   iamRoleARN: ""  # Add the ARN for Flow Logs role
#   logGroupARN: "" # Add the ARN for Flow Logs log group

# natGateway:
#   enabled: true
#   allocationID: ""  # Add your EIP allocation ID
#   subnetID: ""      # Add the subnet ID where the NAT gateway will live

# route53:
#   enabled: true
#   domain: "internal.example.com"

# squid:
#   enabled: false
#   availabilityZones: ["us-east-1a", "us-east-1b"]
#   proxySubnet: "10.0.10.0/24"
#   envVpcID: "vpc-abc123"
#   envSquidName: "squid"
#   organizationName: "MyOrg"
#   networkExpansion: false
#   mainPublicRoute: "rtb-012345"

# csoc:
#   enabled: false
#   pcxID: ""
#   vpcName: ""
#   organizationName: "MyOrg"

# eks:
#   enabled: false
#   vpcID: ""
#   azList: ["us-east-1a", "us-east-1b"]
#   workersSubnetSize: 24
#   secondaryCidrBlock: ""
#   controlPlaneSG: ""
#   nodepoolSG: ""
#   cidrsToRoute: []
#   endpoints:
#     - ec2
#     - sts
#     - autoscaling
#     - ecr-dkr
#     - ecr-api
#     - ebs
#     - logs

# secondary_cidr_block: ""  # Optional CIDR block for secondary VPC associations
# peering_cidr: ""          # CIDR block for VPC peering

# csoc_managed: false
# csoc_account_id: "123456789012"
# peering_vpc_id: "vpc-abcdef"
"""
add_values_stub(values_overrides, controller, ntwk_values_stub1)

vpc_template_stub1_1 = """{{- if .Values.vpc.enabled }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: VPC
metadata:
  name: {{ .Values.vpc.name | quote }}    
  namespace: {{ .Release.Namespace }}-network
spec:
  scope: Namespace
  cidrBlocks:
    - {{ .Values.vpc.cidrBlock }}
  tags:
    {{- range $k, $v := .Values.vpc.tags }}
    - key: {{ $k }}
      value: {{ $v | quote }}
    {{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "vpc.yaml", vpc_template_stub1_1)

# vpc_template_stub1_2 = """
# """
# add_template_stub(template_overrides, controller, "flowlog.yaml", vpc_template_stub1_2)

# vpc_template_stub1_3 = """
# """
# add_template_stub(template_overrides, controller, "natgateway.yaml", vpc_template_stub1_3)

# vpc_template_stub1_4 = """
# """
# add_template_stub(template_overrides, controller, "route53.yaml", vpc_template_stub1_4)

# vpc_template_stub1_5 = """
# """
# add_template_stub(template_overrides, controller, "security_groups.yaml", vpc_template_stub1_5)

# vpc_template_stub1_6 = """
# """
# add_template_stub(template_overrides, controller, "eks_subnets.yaml", vpc_template_stub1_6)

# vpc_template_stub1_7 = """
# """
# add_template_stub(template_overrides, controller, "csoc_peering_connection.yaml", vpc_template_stub1_7)

# vpc_template_stub1_8 = """
# """
# add_template_stub(template_overrides, controller, "db_subnet_group.yaml", vpc_template_stub1_8)

# vpc_helper_stub1_1 = """
# """
# add_template_stub(template_overrides, controller, "helper.tpl", vpc_helper_stub1_1)

vpc_readme_stub1_1 = """### Network Resources on AWS
This chart deploys network resources on AWS using the AWS Controllers for Kubernetes (ACK) framework.
 It includes VPC, subnets, security groups, and other related resources.
"""
add_readme_stub(readme_overrides, controller, vpc_readme_stub1_1)

