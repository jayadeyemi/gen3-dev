#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "peering-controller"
description = "Generic VPC Peering Connection and Accepter for AWS VPC Peering via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
peering_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
peering_chart_stub1 = peering_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, peering_chart_stub1)

peering_values_stub1 = """enabled: true

# Define one or more peering connections
peeringConnections:
  - name: "{{ .Release.Name }}-peer-1"
    # Your local VPC (must exist already or be created by vpc-controller)
    vpcRef:
      name: "{{ .Release.Name }}-vpc"
    # Remote VPC ID & region
    peerVpcId: "vpc-abcdef12"
    peerRegion: "us-east-1"

    # Optional accepter settings
    accepter:
      allowRemoteVpcDnsResolution: true

    # Attach any tags you like
    tags:
      - key: Environment
        value: dev
      - key: Project
        value: "{{ .Release.Name }}"
"""
add_value_override(values_overrides, controller, peering_values_stub1)

peering_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.peeringConnections }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: VPCPeeringConnection
metadata:
  name: {{ .name }}
spec:
  # Local VPC reference
  vpcRef:
    name: {{ .vpcRef.name }}
  # Remote VPC ID & region
  peerVpcId: {{ .peerVpcId | quote }}
  peerRegion: {{ .peerRegion | quote }}
  # Tags (optional)
  tags:
{{- range .tags }}
    - key: {{ .key | quote }}
      value: {{ .value | quote }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "vpc-peering-connection.yaml", peering_template_stub1_1)

peering_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.peeringConnections }}
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: VPCPeeringConnectionAccepter
metadata:
  name: {{ .name }}-accepter
spec:
  # Reference the peering connection created above
  vpcPeeringConnectionRef:
    name: {{ .name }}
  # Whether the accepter should allow DNS resolution from the peer
  allowRemoteVpcDnsResolution: {{ .accepter.allowRemoteVpcDnsResolution }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "vpc-peering-connection-accepter.yaml", peering_template_stub1_2)
