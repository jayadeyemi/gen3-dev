# Daily Report - 2025-06-16

## 🛠️ Tasks Completed
- [x] Deployed Kubernetes Cluster using terraform
- [x] Resolved Version issues with s3 chart
- [x] destroy-eks.sh created to smoothen tests
- [x] Allow user to set random suffix

## 🧠 Learnings
- Using modules makes it difficult to modify resources in place.
- ACK charts are case sensitive

## 🚧 Issues / Blockers
- Entire infrastructure has to be recreated each time

## 📆 Planned for Tomorrow
- "Random" resource needs to be checked if "prevent_destroy" resolved having to destroy each time, we can stabilise resource updates
- Automate controller version injection from map
- Test Cluster and current ACK charts 
