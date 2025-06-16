# apiVersion: eksctl.io/v1alpha5
# kind: Cluster
# metadata:
#   name: dev-cluster
#   region: us-east-1
#   version: "1.27"

# # let eksctl create VPC + subnets for me
# vpc:
#   autoCreate: true

# nodeGroups:
#   - name: ng-dev
#     instanceType: t3.medium
#     desiredCapacity: 2
#     minSize: 1
#     maxSize: 3
#     labels: { role: dev }
#     tags:
#       environment: dev

terraform init
terraform plan -out=tfplan.bin -var-file=secrets.tfvars && terraform show -json tfplan.bin | jq . > plan.json
