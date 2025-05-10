#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "s3-controller"
description = "Generic S3 bucket, bucket policy, bucket logging, bucket lifecycle, bucket versioning, bucket ownership controls, bucket notifications, bucket public access block, bucket server-side encryption via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
s3_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
s3_chart_stub1 = s3_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, s3_chart_stub1)

s3_values_stub1 = """enabled: true

buckets:
  - name: "{{ .Release.Name }}-data-bucket"
    acl: Private
    tags:
      - key: env
        value: "{{ .Release.Namespace }}"
      - key: project
        value: "{{ .Release.Name }}"
    # server-side encryption
    serverSideEncryption:
      rules:
        - applyServerSideEncryptionByDefault:
            sseAlgorithm: AES256
    # logging
    logging:
      targetBucket: "{{ .Release.Name }}-logs"
      targetPrefix: logs/
    # public access block
    publicAccessBlock:
      blockPublicAcls: true
      ignorePublicAcls: true
      blockPublicPolicy: true
      restrictPublicBuckets: true
    # lifecycle rules
    lifecycle:
      rules:
        - id: expire-old
          status: Enabled
          expiration:
            days: 90
    # notifications (SNS)
    notifications:
      topicConfigurations:
        - id: onCreate
          topicArn: arn:aws:sns:us-east-1:123456789012:my-topic
          events:
            - s3:ObjectCreated:*
    # bucket policy
    policy:
      policyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal: "*"
            Action:
              - s3:GetObject
            Resource:
              - "arn:aws:s3:::{{ .Release.Name }}-data-bucket/*"
    # ownership controls
    ownershipControls:
      rules:
        - objectOwnership: BucketOwnerPreferred
    # versioning
    versioning:
      status: Enabled
"""
add_value_override(values_overrides, controller, s3_values_stub1)

s3_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: Bucket
metadata:
  name: {{ .name }}
spec:
  bucketName: {{ .name | quote }}
  acl: {{ .acl }}
  tags:
{{- range .tags }}
    - key: {{ .key | quote }}
      value: {{ .value | quote }}
{{- end }}
{{- end }}
{{- end }}

"""
add_template_stub(template_overrides, controller, "bucket.yaml", s3_template_stub1_1)

s3_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .serverSideEncryption }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketServerSideEncryptionConfiguration
metadata:
  name: {{ .name }}-sse
spec:
  bucketRef:
    name: {{ .name }}
  rules:
{{ toYaml .serverSideEncryption.rules | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-server-side-encryption.yaml", s3_template_stub1_2)

s3_template_stub1_3 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .logging }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketLogging
metadata:
  name: {{ .name }}-logging
spec:
  bucketRef:
    name: {{ .name }}
  targetBucket: {{ .logging.targetBucket | quote }}
  targetPrefix: {{ .logging.targetPrefix | quote }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-logging.yaml", s3_template_stub1_3)

s3_template_stub1_4 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .publicAccessBlock }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketPublicAccessBlock
metadata:
  name: {{ .name }}-publicaccess
spec:
  bucketRef:
    name: {{ .name }}
  blockPublicAcls: {{ .publicAccessBlock.blockPublicAcls }}
  ignorePublicAcls: {{ .publicAccessBlock.ignorePublicAcls }}
  blockPublicPolicy: {{ .publicAccessBlock.blockPublicPolicy }}
  restrictPublicBuckets: {{ .publicAccessBlock.restrictPublicBuckets }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-public-access-block.yaml", s3_template_stub1_4)

s3_template_stub1_5 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .lifecycle }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketLifecycleConfiguration
metadata:
  name: {{ .name }}-lifecycle
spec:
  bucketRef:
    name: {{ .name }}
  rules:
{{ toYaml .lifecycle.rules | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-lifecycle.yaml", s3_template_stub1_5)

s3_template_stub1_6 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .notifications }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketNotification
metadata:
  name: {{ .name }}-notification
spec:
  bucketRef:
    name: {{ .name }}
  topicConfigurations:
{{ toYaml .notifications.topicConfigurations | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-notification.yaml", s3_template_stub1_6)

s3_template_stub1_7 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .policy }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketPolicy
metadata:
  name: {{ .name }}-policy
spec:
  bucketRef:
    name: {{ .name }}
  policyDocument: |
{{ toYaml .policy.policyDocument | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-policy.yaml", s3_template_stub1_7)

s3_template_stub1_8 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .ownershipControls }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketOwnershipControls
metadata:
  name: {{ .name }}-ownership
spec:
  bucketRef:
    name: {{ .name }}
  rules:
{{ toYaml .ownershipControls.rules | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-ownership-controls.yaml", s3_template_stub1_8)

s3_template_stub1_9 = """{{- if .Values.enabled }}
{{- range .Values.buckets }}
{{- if .versioning }}
apiVersion: s3.services.k8s.aws/v1alpha1
kind: BucketVersioning
metadata:
  name: {{ .name }}-versioning
spec:
  bucketRef:
    name: {{ .name }}
  status: {{ .versioning.status }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "bucket-versioning.yaml", s3_template_stub1_9)