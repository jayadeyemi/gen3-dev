#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "kms-controller"
description = "Generic KMS Key, Alias, and Grant Config for AWS KMS via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
kms_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
kms_chart_stub1 = kms_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, kms_chart_stub1)

kms_values_stub1 = """enabled: true

# Create one or more Customer Master Keys
keys:
  - name: {{ .Release.Name }}-cmk
    description: "Customer master key for {{ .Release.Name }}"
    enableKeyRotation: true
    deletionPolicy: Delete    # or Retain

# Create aliases pointing to your CMKs
aliases:
  - name: alias/{{ .Release.Name }}-cmk
    targetKeyRef: {{ .Release.Name }}-cmk

# Create grants on CMKs
grants:
  - name: {{ .Release.Name }}-read-grant
    keyRef: {{ .Release.Name }}-cmk
    granteePrincipal: arn:aws:iam::123456789012:role/MyReaderRole
    operations:
      - Decrypt
      - DescribeKey
  - name: {{ .Release.Name }}-write-grant
    keyRef: {{ .Release.Name }}-cmk
    granteePrincipal: arn:aws:iam::123456789012:role/MyWriterRole
    operations:
      - Encrypt
      - GenerateDataKey
"""
add_value_override(values_overrides, controller, kms_values_stub1)

kms_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.keys }}
apiVersion: kms.services.k8s.aws/v1alpha1
kind: KMSKey
metadata:
  name: {{ .name }}
spec:
  description: {{ .description | quote }}
  enableKeyRotation: {{ .enableKeyRotation }}
  deletionPolicy: {{ .deletionPolicy | quote }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "key.yaml", kms_template_stub1_1)

kms_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.aliases }}
apiVersion: kms.services.k8s.aws/v1alpha1
kind: KMSAlias
metadata:
  # Helm names cannot contain '/', so we sanitize it here
  name: {{ .name | replace "/" "-" }}
spec:
  aliasName: {{ .name | quote }}
  targetKeyRef:
    name: {{ .targetKeyRef }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "alias.yaml", kms_template_stub1_2)

kms_template_stub1_3 = """{{- if .Values.enabled }}
{{- range .Values.grants }}
apiVersion: kms.services.k8s.aws/v1alpha1
kind: KMSGrant
metadata:
  name: {{ .name }}
spec:
  keyRef:
    name: {{ .keyRef }}
  granteePrincipal: {{ .granteePrincipal | quote }}
  operations:
  {{- range .operations }}
    - {{ . | quote }}
  {{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "grant.yaml", kms_template_stub1_3)

