#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "vpc-controller"
description = "Generic VPC + Subnet + IGW + RouteTables via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
vpc_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
vpc_chart_stub1 = vpc_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, vpc_chart_stub1)

vpc_values_stub1 = """enabled: true

vpc:
  cidrBlock: "10.0.0.0/16"

subnets:
  - name: "subnet-a"
    cidrBlock: "10.0.1.0/24"
  - name: "subnet-b"
    cidrBlock: "10.0.2.0/24"

internetGateway:
  name: "igw"

routeTables:
  - name: "rtb-public"
    vpcRef: { name: "{{ .Release.Name }}-vpc" }
    routes:
      - cidrBlock: "0.0.0.0/0"
        gatewayId: "{{ .Values.internetGateway.name }}"

flowLogs:
  enabled: true
  logGroupName: "/aws/vpc/flowlogs"

peering:
  name: "peer-to-csoc"
  peerVpcId: "vpc-xxxx"
  peerRegion: "us-east-1"
"""
add_value_override(values_overrides, controller, vpc_values_stub1)

vpc_template_stub1_1 = """{{- if .Values.enabled }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: VPC
metadata:
  name: {{ .Release.Name }}-vpc
spec:
  cidrBlock: {{ .Values.vpc.cidrBlock | quote }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "vpc.yaml", vpc_template_stub1_1)

vpc_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.subnets }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: Subnet
metadata:
  name: {{ .name }}
spec:
  cidrBlock: {{ .cidrBlock | quote }}
  vpcRef:
    name: {{ $.Release.Name }}-vpc
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "subnet.yaml", vpc_template_stub1_2)
