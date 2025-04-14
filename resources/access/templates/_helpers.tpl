{{/*
Generate the S3 Origin ID for CloudFront distribution.
Format: S3-Website-<accessUrl>.s3-website-<region>.amazonaws.com
*/}}
{{- define "helm-access.s3OriginID" -}}
S3-Website-{{ .Values.accessUrl }}.s3-website-{{ .Values.region }}.amazonaws.com
{{- end -}}