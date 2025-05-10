#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "route53-controller"
description = "Generic Route53 HostedZone, record sets, and visibility config for AWS Route53 via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
route53_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
route53_chart_stub1 = route53_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, route53_chart_stub1)

route53_values_stub1 = """enabled: true

# Define one or more hosted zones
zones:
  - name: "example.com"           # your domain
    comment: "Primary zone"
    # Optionally associate with a VPC for private zones
    vpc:
      id: "vpc-0123456789abcdef0"
      region: "us-east-1"

# Define DNS records in those zones
recordSets:
  - name: "www.example.com"       # full record name
    zoneName: "example.com"       # must match one of the above
    type: "A"
    ttl: 300
    resourceRecords:
      - "1.2.3.4"
  - name: "api.example.com"
    zoneName: "example.com"
    type: "CNAME"
    ttl: 300
    resourceRecords:
      - "elb-012345.elb.amazonaws.com"
"""
add_value_override(values_overrides, controller, route53_values_stub1)

route53_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.zones }}
apiVersion: route53.services.k8s.aws/v1alpha1
kind: HostedZone
metadata:
  name: {{ .name | replace "." "-" }}-zone
spec:
  name: {{ .name | quote }}
  comment: {{ .comment | quote }}
  {{- if .vpc }}
  vpcs:
    - id: {{ .vpc.id | quote }}
      region: {{ .vpc.region | quote }}
  {{- end }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "hosted-zone.yaml", route53_template_stub1_1)

route53_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.recordSets }}
apiVersion: route53.services.k8s.aws/v1alpha1
kind: RecordSet
metadata:
  name: {{ .name | replace "." "-" }}-{{ .type | lower }}
spec:
  hostedZoneName: {{ .zoneName | quote }}
  recordType: {{ .type | quote }}
  ttl: {{ .ttl }}
  resourceRecords:
{{ toYaml .resourceRecords | indent 4 }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "record-set.yaml", route53_template_stub1_2)

