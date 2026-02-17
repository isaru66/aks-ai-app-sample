helm template ai-app --output-dir ./output 

# with values file
helm template ai-app -f ./ai-app/environments/dev-values.yaml  --output-dir ./output