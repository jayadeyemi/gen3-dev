#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "ec2-controller"
description = "Generic EC2 Key Pair, EIP, Launch Template, and Security Group Config for AWS EC2 via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
ec2_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
ec2_chart_stub1 = ec2_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, ec2_chart_stub1)

ec2_values_stub1 = """enabled: true

# 1) SSH key pairs
keyPairs:
  - name: "{{ .Release.Name }}-key"
    publicKeyMaterial: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."

# 2) Elastic IPs
eips:
  - name: "{{ .Release.Name }}-eip"
    domain: "vpc"

# 3) Launch Templates
launchTemplates:
  - name: "{{ .Release.Name }}-lt"
    launchTemplateData:
      instanceType: "t3.micro"
      imageId: "ami-0123456789abcdef0"
      keyName: "{{ .Values.keyPairs._0.name }}"
      networkInterfaces:
        - deviceIndex: 0
          subnetRef:
            name: "{{ .Values.subnets._0.name }}"
          securityGroupRefs:
            - name: "{{ .Values.securityGroups._0.name }}"

# 4) Security Groups
securityGroups:
  - name: "{{ .Release.Name }}-sg-ssh"
    description: "Allow SSH"
    vpcRef:
      name: "{{ .Values.vpcController.vpc.name }}"
    ingress:
      - ipProtocol: "tcp"
        fromPort: 22
        toPort: 22
        cidrBlocks:
          - "0.0.0.0/0"
    egress:
      - ipProtocol: "-1"
        fromPort: 0
        toPort: 0
        cidrBlocks:
          - "0.0.0.0/0"
"""
add_value_override(values_overrides, controller, ec2_values_stub1)

ec2_template_stub1_1 = """{{- if .Values.enabled }}
{{- range $i, $kp := .Values.keyPairs }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: KeyPair
metadata:
  name: {{ $kp.name }}
spec:
  publicKeyMaterial: {{ $kp.publicKeyMaterial | quote }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "key-pair.yaml", ec2_template_stub1_1)

ec2_template_stub1_2 = """{{- if .Values.enabled }}
{{- range $i, $eip := .Values.eips }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: EIP
metadata:
  name: {{ $eip.name }}
spec:
  domain: {{ $eip.domain | quote }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "eip.yaml", ec2_template_stub1_2)

ec2_template_stub1_3 = """{{- if .Values.enabled }}
{{- range $i, $lt := .Values.launchTemplates }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: LaunchTemplate
metadata:
  name: {{ $lt.name }}
spec:
  launchTemplateName: {{ $lt.name | quote }}
  launchTemplateData:
{{ toYaml $lt.launchTemplateData | indent 4 }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "launch-template.yaml", ec2_template_stub1_3)

ec2_template_stub1_4 = """{{- if .Values.enabled }}
{{- range $i, $sg := .Values.securityGroups }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: SecurityGroup
metadata:
  name: {{ $sg.name }}
spec:
  description: {{ $sg.description | quote }}
  vpcRef:
    name: {{ $sg.vpcRef.name }}
{{- if $sg.ingress }}
  ingress:
{{ toYaml $sg.ingress | indent 4 }}
{{- end }}
{{- if $sg.egress }}
  egress:
{{ toYaml $sg.egress | indent 4 }}
{{- end }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "security-group.yaml", ec2_template_stub1_4)