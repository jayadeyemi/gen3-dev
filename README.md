 ## Quickstart

+ create both Kind clusters and register the “app” cluster with Argo CD

```bash
- chmod +x scripts/*.sh
- scripts/setup-kind.sh
+ # 1) Create CSOC cluster (Argo CD + controllers)
+ kind create cluster --name csoc --config kind/csoc-kind-config.yaml
+
+ # 2) Create App cluster (your application workloads)
+ kind create cluster --name app --config kind/app-kind-config.yaml
+
+ # 3) Bootstrap only CSOC cluster with your umbrella chart
+ #    (this installs Argo CD, all controllers, plus the ApplicationSet)
+ scripts/bootstrap-helm.sh dev --context kind-csoc

+ # 4) Register “app” cluster with Argo CD
+ #    (so Argo CD can push your app into that cluster)
+ kubectl port-forward svc/argocd-server -n argocd --context kind-csoc 8080:443 &
+ ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
+   --context kind-csoc -o jsonpath="{.data.password}" | base64 -d)
+ argocd login localhost:8080 --username admin --password "$ARGO_PWD" --insecure
+ argocd cluster add kind-app --name app --context kind-app

+ # 5) Browse Argo CD UI at https://localhost:8080 (user/pass: admin/$ARGO_PWD)
