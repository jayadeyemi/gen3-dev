#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "elasticsearch-controller"
description = "Generic Elasticsearch Domain and Access Policy Config for AWS Elasticsearch via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
elasticsearch_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
elasticsearch_chart_stub1 = elasticsearch_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, elasticsearch_chart_stub1)

elasticsearch_values_stub1 = """enabled: true

# Define one or more ES domains
domains:
  - name: "{{ .Release.Name }}-es"
    version: "7.10"
    clusterConfig:
      instanceType: "t3.small.elasticsearch"
      instanceCount: 2
      zoneAwarenessEnabled: true
      zoneAwarenessConfig:
        availabilityZoneCount: 2
    ebsOptions:
      ebsEnabled: true
      volumeType: "gp2"
      volumeSize: 20
    accessPolicies:
      # IAM policy JSON allowing access from specific principal(s)
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Principal:
            AWS: ["arn:aws:iam::123456789012:role/MyESAccessRole"]
          Action: "es:*"
          Resource: "arn:aws:es:{{ .Values.region }}:{{ .Values.accountId }}:domain/{{ .Release.Name }}-es/*"
"""
add_value_override(values_overrides, controller, elasticsearch_values_stub1)

elasticsearch_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.domains }}
apiVersion: elasticsearch.services.k8s.aws/v1alpha1
kind: ElasticsearchDomain
metadata:
  name: {{ .name }}
spec:
  domainName: {{ .name | quote }}
  elasticsearchVersion: {{ .version | quote }}
  clusterConfig:
    instanceType: {{ .clusterConfig.instanceType | quote }}
    instanceCount: {{ .clusterConfig.instanceCount }}
    zoneAwarenessEnabled: {{ .clusterConfig.zoneAwarenessEnabled }}
    {{- if .clusterConfig.zoneAwarenessConfig }}
    zoneAwarenessConfig:
      availabilityZoneCount: {{ .clusterConfig.zoneAwarenessConfig.availabilityZoneCount }}
    {{- end }}
  ebsOptions:
    ebsEnabled: {{ .ebsOptions.ebsEnabled }}
    volumeType: {{ .ebsOptions.volumeType | quote }}
    volumeSize: {{ .ebsOptions.volumeSize }}
  accessPolicies: |
{{ toYaml .accessPolicies | indent 4 }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "domain.yaml", elasticsearch_template_stub1_1)
