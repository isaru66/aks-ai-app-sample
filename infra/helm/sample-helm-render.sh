helm template ai-app --output-dir ./output 

# with values file
helm template ai-app -f ./ai-app/environments/dev-values.yaml  --output-dir ./output

helm template ai-app -f ./ai-app/environments/dev-values.yaml -f ./ai-app/environments/secret.yaml  --output-dir ./output

# to pass in file.
helm upgrade ai-app ./ai-app \
  --set gateway.tls.create=true \
  --set-file gateway.tls.crt=tls.crt \
  --set-file gateway.tls.key=tls.key