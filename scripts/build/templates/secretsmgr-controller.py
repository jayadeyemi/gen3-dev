#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "secretsmgr-controller"
description = "Generic Secrets Manager Secret and SecretVersion Config for AWS Secrets Manager via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
secretsmgr_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
secretsmgr_chart_stub1 = secretsmgr_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, secretsmgr_chart_stub1)

secretsmgr_values_stub1 = """enabled: true

# Define one or more Secrets
secrets:
  - name: "{{ .Release.Name }}-app-secret"
    description: "Application credentials"
    # Provide either secretString or reference to an existing K8s Secret
    secretString: '{"username":"admin","password":"s3cr3t"}'
    # Optional: encrypt with a specific KMS key
    kmsKeyId: "arn:aws:kms:us-east-1:123456789012:key/abcdefg-1234-5678-9012-abcdefg"

# Optionally create explicit SecretVersions (e.g. rotate)
secretVersions:
  - name: "{{ .Release.Name }}-app-secret-ver1"
    secretRefName: "{{ .Release.Name }}-app-secret"
    secretString: '{"username":"admin","password":"n3wp4ss"}'
"""
add_value_override(values_overrides, controller, secretsmgr_values_stub1)

secretsmgr_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.secrets }}
apiVersion: secretsmanager.services.k8s.aws/v1alpha1
kind: Secret
metadata:
  name: {{ .name }}
spec:
  name: {{ .name }}
  description: {{ .description | quote }}
  {{- if .secretString }}
  secretString: {{ .secretString | quote }}
  {{- end }}
  {{- if .secretBinary }}
  secretBinary: {{ .secretBinary | quote }}
  {{- end }}
  {{- if .kmsKeyId }}
  kmsKeyId: {{ .kmsKeyId | quote }}
  {{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "secret.yaml", secretsmgr_template_stub1_1)

secretsmgr_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.secretVersions }}
apiVersion: secretsmanager.services.k8s.aws/v1alpha1
kind: SecretVersion
metadata:
  name: {{ .name }}
spec:
  secretRef:
    name: {{ .secretRefName }}
  {{- if .secretString }}
  secretString: {{ .secretString | quote }}
  {{- end }}
  {{- if .secretBinary }}
  secretBinary: {{ .secretBinary | quote }}
  {{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "secret-version.yaml", secretsmgr_template_stub1_2)
