#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "cloudtrail-controller"
description = "Generic CloudTrail Trail and Log Config for AWS CloudTrail via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
cloudtrail_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
cloudtrail_chart_stub1 = cloudtrail_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, cloudtrail_chart_stub1)

cloudtrail_values_stub1 = """enabled: true

# Define one or more CloudTrail trails
trails:
  - name: "{{ .Release.Name }}-audit-trail"
    s3BucketName: "my-cloudtrail-bucket"
    s3KeyPrefix: "logs/"
    includeGlobalServiceEvents: true
    isMultiRegionTrail: false
    enableLogging: true
    enableLogFileValidation: false
    # Optional:
    kmsKeyId: ""          # e.g. arn:aws:kms:us-east-1:123456789012:key/abcd...
    snsTopicName: ""      # e.g. my-sns-topic
"""
add_value_override(values_overrides, controller, cloudtrail_values_stub1)

cloudtrail_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.trails }}
apiVersion: cloudtrail.services.k8s.aws/v1alpha1
kind: Trail
metadata:
  name: {{ .name }}
spec:
  s3BucketName: {{ .s3BucketName | quote }}
  s3KeyPrefix: {{ .s3KeyPrefix | quote }}
  includeGlobalServiceEvents: {{ .includeGlobalServiceEvents }}
  isMultiRegionTrail: {{ .isMultiRegionTrail }}
  enableLogFileValidation: {{ .enableLogFileValidation }}
  enableLogging: {{ .enableLogging }}
  {{- if .kmsKeyId }}
  kmsKeyId: {{ .kmsKeyId | quote }}
  {{- end }}
  {{- if .snsTopicName }}
  snsTopicName: {{ .snsTopicName | quote }}
  {{- end }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "trail.yaml", cloudtrail_template_stub1_1)
