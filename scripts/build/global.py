#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = 'ack-controller'
description = 'Chart for Global Resources on AWS'
add_description_override(full_descriptions, controller, description)

# Chart.yaml stub
glob_chart_stub1 = Template('''apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.1
type: application
appVersion: "master"

dependencies:
  - name: ack-controllers
    version: 46.22.5
    repository: "oci://public.ecr.aws/aws-controllers-k8s/ack-chart"
''')
glob_chart_stub1 = glob_chart_stub1.substitute(controller=controller, descriptions=description)
add_chart_stub(chart_overrides, controller, 'Chart.yaml', glob_chart_stub1)

# values.yaml stub
glob_values_stub1 = '''# Default values for global chart
global:
  enabled: true
  vpcName: "Commons1"
  organization: "Basic Service"

# controller enabled?
acm:
  enabled: false
acmpca:
  enabled: false
applicationautoscaling:
  enabled: false
cloudfront:
  enabled: false
cloudtrail:
  enabled: false
cloudwatch:
  enabled: false
cloudwatchlogs:
  enabled: false
ec2:
  enabled: false
ecr:
  enabled: false
ecs:
  enabled: false
eks:
  enabled: false
elbv2:
  enabled: false
emrcontainers:
  enabled: false
iam:
  enabled: false
kms:
  enabled: false
lambda:
  enabled: false
opensearchservice:
  enabled: false
rds:
  enabled: false
route53resolver:
  enabled: false
s3:
  enabled: false
s3control:
  enabled: false
secretsmanager:
  enabled: false
sns:
  enabled: false
sqs:
  enabled: false
wafv2:
  enabled: false
'''
add_value_override(values_overrides, controller, glob_values_stub1)
