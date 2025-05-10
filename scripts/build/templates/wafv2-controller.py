#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "wafv2-controller"
description = "Generic WAFv2 WebACL, rules, and visibility config for AWS WAFv2 via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
wafv2_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
wafv2_chart_stub1 = wafv2_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, wafv2_chart_stub1)

wafv2_values_stub1 = """# Global on/off switch (inherits from parent: `rulegroup.enabled`)
wafv2:
  enabled: true

# --- spec fields for RuleGroup ---
name: my-rg
capacity: 100
description: "Example RuleGroup"
scope: REGIONAL

visibilityConfig:
  sampledRequestsEnabled: true
  cloudWatchMetricsEnabled: true
  metricName: rg-metrics

customResponseBodies: {}
rules: []
"""
add_value_override(values_overrides, controller, wafv2_values_stub1)

wafv2_template_stub1_1 = """{{- if .Values.enabled }}
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: rulegroups.wafv2.services.k8s.aws
spec:
  group: wafv2.services.k8s.aws
  scope: Namespaced
  names:
    plural: rulegroups
    singular: rulegroup
    kind: RuleGroup
    listKind: RuleGroupList
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          # … paste your full v1alpha1 schema here …
      subresources:
        status: {}
{{- end }}
"""
add_value_override(values_overrides, controller, wafv2_template_stub1_1)

wafv2_template_stub1_2 = """{{- if .Values.enabled }}
apiVersion: wafv2.services.k8s.aws/v1alpha1
kind: RuleGroup
metadata:
  name: {{ include "rulegroup.fullname" . }}
  namespace: {{ .Release.Namespace }}           # ← inherit the release namespace
  labels:
{{ include "rulegroup.labels" . | indent 2 }}
spec:
  name: {{ .Values.name | quote }}
  capacity: {{ .Values.capacity }}
  scope: {{ .Values.scope | upper | quote }}
  description: {{ .Values.description | quote }}
  visibilityConfig:
{{ toYaml .Values.visibilityConfig | indent 4 }}
  {{- if .Values.customResponseBodies }}
  customResponseBodies:
{{ toYaml .Values.customResponseBodies | indent 4 }}
  {{- end }}
  {{- if .Values.rules }}
  rules:
{{- range .Values.rules }}
{{ include "rulegroup.ruleEntry" . | indent 4 }}
{{- end }}
  {{- end }}
{{- end }}

"""
add_template_stub(template_overrides, controller, "web-acl.yaml", wafv2_template_stub1_2)

wafv2_helper_stub1_1 = """{{- define "rulegroup.fullname" -}}
{{ printf "%s-%s" .Release.Name .Values.name }}
{{- end }}

{{- define "rulegroup.labels" -}}
app.kubernetes.io/name: {{ include "rulegroup.fullname" . }}
helm.sh/chart: rulegroup-{{ .Chart.Version }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "rulegroup.ruleEntry" -}}
- name: {{ .name | quote }}
  priority: {{ .priority }}
  action:
    {{- if .action.allow }}
    allow: {{ toYaml .action.allow | nindent 6 }}
    {{- else if .action.block }}
    block: {{ toYaml .action.block | nindent 6 }}
    {{- end }}
  statement: {{ toYaml .statement | nindent 4 }}
  {{- if .ruleLabels }}
  ruleLabels: {{ toYaml .ruleLabels | nindent 4 }}
  {{- end }}
  {{- if .overrideAction }}
  overrideAction: {{ toYaml .overrideAction | nindent 2 }}
  {{- end }}
  {{- if .visibilityConfig }}
  visibilityConfig: {{ toYaml .visibilityConfig | nindent 4 }}
  {{- end }}
{{- end }}
"""
add_helper_stub(helper_overrides, controller, "helpers.tpl", wafv2_helper_stub1_1)