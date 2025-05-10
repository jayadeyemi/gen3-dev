#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = "rds-controller"
description = "Generic RDS DB Cluster + Instance via ACK"
add_description_override(full_descriptions, controller, description)

# insert controller name into chart stub
rds_chart_stub1 = Template("""apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.0
appVersion: "latest"
""")
rds_chart_stub1 = rds_chart_stub1.substitute(controller=controller, descriptions=description)
add_value_override(chart_overrides, controller, rds_chart_stub1)

rds_values_stub1 = """enabled: true

dbSubnetGroups:
  - name: "db-subnets"
    subnetRefs:
      - name: "{{ .Release.Name }}-subnet-1"
      - name: "{{ .Release.Name }}-subnet-2"

dbParameterGroups:
  - name: "db-params"
    family: "mysql8.0"

dbInstances:
  - name: "{{ .Release.Name }}-db"
    engine: mysql
    instanceClass: db.t3.micro
    dbSubnetGroupName: "db-subnets"
    parameterGroupName: "db-params"
    masterUsername: admin
    masterUserPassword:
      fromSecret:
        name: mydb-secret
        key: password
"""
add_value_override(values_overrides, controller, rds_values_stub1)

rds_template_stub1_1 = """{{- if .Values.enabled }}
{{- range .Values.dbSubnetGroups }}
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBSubnetGroup
metadata:
  name: {{ .name }}
spec:
  subnetRefs:
{{- range .subnetRefs }}
    - name: {{ .name }}
{{- end }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "db-subnet-group.yaml", rds_template_stub1_1)

rds_template_stub1_2 = """{{- if .Values.enabled }}
{{- range .Values.dbParameterGroups }}
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBParameterGroup
metadata:
  name: {{ .name }}
spec:
  family: {{ .family | quote }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "db-parameter-group.yaml", rds_template_stub1_2)

rds_template_stub1_3 = """{{- if .Values.enabled }}
{{- range .Values.dbInstances }}
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBInstance
metadata:
  name: {{ .name }}
spec:
  dbInstanceClass: {{ .instanceClass | quote }}
  engine: {{ .engine | quote }}
  masterUsername: {{ .masterUsername | quote }}
  masterUserPassword:
    fromSecret:
      name: {{ .masterUserPassword.fromSecret.name }}
      key: {{ .masterUserPassword.fromSecret.key }}
  dbSubnetGroupName: {{ .dbSubnetGroupName | quote }}
  dbParameterGroupName: {{ .parameterGroupName | quote }}
{{- end }}
{{- end }}
"""
add_template_stub(template_overrides, controller, "db-instance.yaml", rds_template_stub1_3)