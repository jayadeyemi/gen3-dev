#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "sqs-controller"
description = "Generic SQS Queue, Queue Policy, and Visibility Config for AWS SQS via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
sqs_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
sqs_chart_stub1 = sqs_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, sqs_chart_stub1)

sqs_values_stub1 = """enabled: true

# Define one or more SQS Queues
queues:
  - name: "{{ .Release.Name }}-queue-1"
    visibilityTimeout: 30
    messageRetentionSeconds: 1209600  # 14 days
    delaySeconds: 0
    receiveMessageWaitTimeSeconds: 0
  - name: "{{ .Release.Name }}-queue-2"
    visibilityTimeout: 45
    messageRetentionSeconds: 345600   # 4 days
    delaySeconds: 5
    receiveMessageWaitTimeSeconds: 20

# (Optional) Attach a policy to a queue
queuePolicies:
  - name: "{{ .Release.Name }}-queue-1-policy"
    queueRef:
      name: "{{ .Release.Name }}-queue-1"
    policyDocument:
      Version: "2012-10-17"
      Statement:
        - Effect: Allow
          Principal: "*"
          Action:
            - "sqs:SendMessage"
            - "sqs:ReceiveMessage"
          Resource: "*"
"""
add_value_override(values_overrides, controller, sqs_values_stub1)

sqs_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.queues }}
apiVersion: sqs.services.k8s.aws/v1alpha1
kind: Queue
metadata:
  name: {{ .name }}
spec:
  visibilityTimeout: {{ .visibilityTimeout }}
  messageRetentionSeconds: {{ .messageRetentionSeconds }}
  delaySeconds: {{ .delaySeconds }}
  receiveMessageWaitTimeSeconds: {{ .receiveMessageWaitTimeSeconds }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "queue.yaml", sqs_template_stub1_1)

sqs_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.queuePolicies }}
apiVersion: sqs.services.k8s.aws/v1alpha1
kind: QueuePolicy
metadata:
  name: {{ .name }}
spec:
  queueRef:
    name: {{ .queueRef.name }}
  policyDocument: |
{{ toYaml .policyDocument | indent 4 }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "queue-policy.yaml", sqs_template_stub1_2)