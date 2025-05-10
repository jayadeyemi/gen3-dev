#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "iam-controller"
description = "Generic IAM Roles, Policies, Attachments via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
iam_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
iam_chart_stub1 = iam_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, iam_chart_stub1)

iam_values_stub1 = """enabled: true

roles:
  - name: "example-role"
    assumeRolePolicyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Principal: { Service: [lambda.amazonaws.com] }
          Action: sts:AssumeRole

policies:
  - name: "example-policy"
    policyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Action: [logs:CreateLogGroup]
          Resource: "*"

rolePolicyAttachments:
  - name: "attach-example"
    roleName: "example-role"
    policyName: "example-policy"
"""
add_value_override(values_overrides, controller, iam_values_stub1)

iam_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.roles }}
apiVersion: identitymanagement.services.k8s.aws/v1alpha1
kind: Role
metadata:
  name: {{ .name }}
spec:
  assumeRolePolicyDocument: |
{{ toYaml .assumeRolePolicyDocument | indent 4 }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "role.yaml", iam_template_stub1_1)

iam_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.policies }}
apiVersion: identitymanagement.services.k8s.aws/v1alpha1
kind: Policy
metadata:
  name: {{ .name }}
spec:
  policyDocument: |
{{ toYaml .policyDocument | indent 4 }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "policy.yaml", iam_template_stub1_2)

iam_template_stub1_3 = """{{- if .Values.enabled }}
{{- range .Values.rolePolicyAttachments }}
apiVersion: identitymanagement.services.k8s.aws/v1alpha1
kind: RolePolicyAttachment
metadata:
  name: {{ .name }}
spec:
  roleRef:
    name: {{ .roleName }}
  policyRef:
    name: {{ .policyName }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "role-policy-attachment.yaml", iam_template_stub1_3)