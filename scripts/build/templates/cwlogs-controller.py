#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "cwlogs-controller"
description = "Generic CloudWatch Logs LogGroup, ResourcePolicy, and SubscriptionFilter Config for AWS CloudWatch Logs via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
cwlogs_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
cwlogs_chart_stub1 = cwlogs_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, cwlogs_chart_stub1)

cwlogs_values_stub1 = """enabled: true

# Define one or more LogGroups
logGroups:
  - name: "{{ .Release.Name }}-app-logs"      # metadata.name
    logGroupName: "/aws/app/logs"            # spec.logGroupName
    retentionInDays: 14                      # spec.retentionInDays

# Define one or more ResourcePolicies
resourcePolicies:
  - name: "{{ .Release.Name }}-cw-policy"    # metadata.name
    policyName: "cw-resource-policy"         # spec.policyName
    policyDocument: |
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "AllowAll",
            "Effect": "Allow",
            "Principal": "*",
            "Action": ["logs:PutLogEvents"],
            "Resource": "*"
          }
        ]
      }

# Define one or more SubscriptionFilters
subscriptionFilters:
  - name: "{{ .Release.Name }}-sub-filter"   # metadata.name
    filterName: "ErrorFilter"                # spec.filterName
    filterPattern: "[ERROR]"                 # spec.filterPattern
    destinationArn:                          # spec.destinationArn
      "arn:aws:logs:us-east-1:123456789012:log-group:dest-logs"
    logGroupRef:
      name: "{{ .Release.Name }}-app-logs"   # points to the above LogGroup
"""
add_value_override(values_overrides, controller, cwlogs_values_stub1)

cwlogs_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.logGroups }}
apiVersion: logs.services.k8s.aws/v1alpha1
kind: LogGroup
metadata:
  name: {{ .name }}
spec:
  logGroupName: {{ .logGroupName | quote }}
  retentionInDays: {{ .retentionInDays }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "log-group.yaml", cwlogs_template_stub1_1)

cwlogs_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.resourcePolicies }}
apiVersion: logs.services.k8s.aws/v1alpha1
kind: ResourcePolicy
metadata:
  name: {{ .name }}
spec:
  policyName: {{ .policyName | quote }}
  policyDocument: |
{{ toYaml .policyDocument | indent 4 }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "resource-policy.yaml", cwlogs_template_stub1_2)

cwlogs_template_stub1_3 = """{{- if .Values.enabled }}
{{- range .Values.subscriptionFilters }}
apiVersion: logs.services.k8s.aws/v1alpha1
kind: SubscriptionFilter
metadata:
  name: {{ .name }}
spec:
  filterName: {{ .filterName | quote }}
  filterPattern: {{ .filterPattern | quote }}
  destinationArn: {{ .destinationArn | quote }}
  logGroupRef:
    name: {{ .logGroupRef.name }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "subscription-filter.yaml", cwlogs_template_stub1_3)

