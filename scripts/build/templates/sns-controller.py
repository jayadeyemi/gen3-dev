#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "sns-controller"
description = "Generic SNS Topic, Subscription, and Policy Config for AWS SNS via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
sns_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
sns_chart_stub1 = sns_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, sns_chart_stub1)

sns_values_stub1 = """# Toggle the entire subchart on/off
enabled: true

# 1) Topics to create
topics:
  - name: "{{ .Release.Name }}-alerts-topic"
    displayName: "Alerts Topic"
    # (optional) KMS master key for encrypting messages
    # kmsMasterKeyID: arn:aws:kms:us-east-1:123456789012:key/abcd-...

# 2) Subscriptions to attach to topics
subscriptions:
  - name: "{{ .Release.Name }}-email-sub"
    protocol: email
    endpoint: "ops@example.com"
    # reference one of the topics above
    topicRef: "{{ .Release.Name }}-alerts-topic"

# 3) Topic policies
policies:
  - name: "{{ .Release.Name }}-alerts-policy"
    topicRef: "{{ .Release.Name }}-alerts-topic"
    # standard IAM policy document
    policyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Principal: "*"
          Action:
            - "SNS:Publish"
          Resource: "*"
"""
add_value_override(values_overrides, controller, sns_values_stub1)

sns_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.topics }}
apiVersion: sns.services.k8s.aws/v1alpha1
kind: Topic
metadata:
  name: {{ .name }}
spec:
  displayName: {{ .displayName | quote }}
  {{- if .kmsMasterKeyID }}
  kmsMasterKeyID: {{ .kmsMasterKeyID | quote }}
  {{- end }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "topic.yaml", sns_template_stub1_1)

sns_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.subscriptions }}
apiVersion: sns.services.k8s.aws/v1alpha1
kind: Subscription
metadata:
  name: {{ .name }}
spec:
  protocol: {{ .protocol | quote }}
  endpoint: {{ .endpoint | quote }}
  topicRef:
    name: {{ .topicRef }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "subscription.yaml", sns_template_stub1_2)

sns_template_stub1_3 = """{{- if .Values.enabled }}
{{- range .Values.policies }}
apiVersion: sns.services.k8s.aws/v1alpha1
kind: TopicPolicy
metadata:
  name: {{ .name }}
spec:
  topicRef:
    name: {{ .topicRef }}
  policyDocument: |
{{ toYaml .policyDocument | indent 4 }}
---
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "topic-policy.yaml", sns_template_stub1_3)

