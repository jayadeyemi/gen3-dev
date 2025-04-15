aws cloudformation create-stack \
  --stack-name MyStackName \
  --template-body Phase1.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
