# AI Foundry Module Not Created - Diagnostic Guide

## Issue

The AI Foundry module is not being created even though all flags appear to be enabled.

## Check AI Foundry Module Condition

The AI Foundry module has a complex condition:

```hcl
module "ai_foundry" {
  count = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? 1 : 0
  # ...
}
```

All of these must be `true`:
1. ✅ `enable_ai_foundry = true`
2. ✅ `enable_ai_services = true`
3. ✅ `enable_storage = true`
4. ✅ `enable_keyvault = true`

## Diagnostic Steps

### Step 1: Check Terraform Plan Output

```bash
cd infra/terraform
terraform plan -var-file=environments/dev.tfvars 2>&1 | grep -A 5 "module.ai_foundry"
```

Look for:
- `module.ai_foundry[0]` - Module will be created ✅
- `module.ai_foundry (0 resources)` - Module is disabled ❌

### Step 2: Check Variable Values

```bash
# Check what Terraform sees
terraform console -var-file=environments/dev.tfvars

# In console, check each variable:
> var.enable_ai_foundry
> var.enable_ai_services
> var.enable_storage
> var.enable_keyvault

# Check the full condition
> var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault

# Exit console
> exit
```

### Step 3: Verify Environment File

```bash
# Check dev.tfvars
grep "enable_" environments/dev.tfvars
```

Expected output:
```
enable_ai_foundry        = true
enable_content_safety    = true
enable_private_endpoints = false
enable_monitoring        = true
enable_keyvault          = true
enable_acr               = true
enable_aks               = true
enable_storage           = true
enable_cosmosdb          = false
enable_ai_services       = true
enable_azure_search_service = false
```

### Step 4: Check Module Creation Order

```bash
# Run terraform plan and check module creation
terraform plan -var-file=environments/dev.tfvars > plan.txt

# Check what modules are being created
grep -E "module\.(monitoring|keyvault|storage|ai_services|ai_foundry)" plan.txt
```

## Common Causes

### Cause 1: One or More Modules Disabled

If any dependency is disabled, AI Foundry won't be created:

```hcl
enable_ai_services = false  # ❌ AI Foundry will be disabled
enable_storage     = false  # ❌ AI Foundry will be disabled
enable_keyvault    = false  # ❌ AI Foundry will be disabled
```

**Solution:** Enable all dependencies:
```hcl
enable_ai_foundry  = true
enable_ai_services = true
enable_storage     = true
enable_keyvault    = true
```

### Cause 2: Wrong Variable File

Using different tfvars file than expected:

**Solution:** Explicitly specify the file:
```bash
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

### Cause 3: Variable Override

Variables might be overridden by environment variables or CLI flags:

**Solution:** Check for TF_VAR environment variables:
```bash
# Windows PowerShell
Get-ChildItem Env:TF_VAR_*

# Clear if found
Remove-Item Env:TF_VAR_enable_ai_foundry -ErrorAction SilentlyContinue
```

### Cause 4: Terraform State Issue

Old state might have the module disabled:

**Solution:** Refresh state:
```bash
terraform refresh -var-file=environments/dev.tfvars
terraform plan -var-file=environments/dev.tfvars
```

## Quick Fix

### Option 1: Explicit Enable in Command Line

```bash
terraform plan \
  -var-file=environments/dev.tfvars \
  -var="enable_ai_foundry=true" \
  -var="enable_ai_services=true" \
  -var="enable_storage=true" \
  -var="enable_keyvault=true"
```

### Option 2: Simplify Condition Temporarily

Edit `main.tf` temporarily for debugging:

```hcl
# Temporary - simplified condition
module "ai_foundry" {
  count  = var.enable_ai_foundry ? 1 : 0  # Simplified
  source = "./modules/ai-foundry"
  # ...
}
```

Run plan to see if it's created. If yes, the issue is with one of the dependency checks.

### Option 3: Add Debug Output

Add to `outputs.tf`:

```hcl
output "debug_ai_foundry_condition" {
  value = {
    enable_ai_foundry  = var.enable_ai_foundry
    enable_ai_services = var.enable_ai_services
    enable_storage     = var.enable_storage
    enable_keyvault    = var.enable_keyvault
    all_conditions     = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault
    module_count       = var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault ? 1 : 0
  }
}
```

Then run:
```bash
terraform plan -var-file=environments/dev.tfvars
```

Check the output to see which condition is false.

## Verification

After fix, verify module will be created:

```bash
terraform plan -var-file=environments/dev.tfvars | grep "ai_foundry"
```

Should show:
```
# module.ai_foundry[0].azurerm_ai_foundry.hub will be created
# module.ai_foundry[0].azurerm_ai_foundry_project.project will be created
```

## Current Module Status

Run this to see all module counts:

```bash
terraform plan -var-file=environments/dev.tfvars 2>&1 | grep -E "module\.[a-z_]+\[" | head -20
```

Should show:
- `module.monitoring[0]` ✅
- `module.keyvault[0]` ✅
- `module.storage[0]` ✅
- `module.ai_services[0]` ✅
- `module.ai_foundry[0]` ✅ (should appear if condition is true)

## Expected Behavior

With all flags enabled in `dev.tfvars`:

```hcl
enable_ai_foundry  = true
enable_ai_services = true
enable_storage     = true
enable_keyvault    = true
```

The condition evaluates to:
```
true && true && true && true = true
? 1 : 0 = 1
```

Result: `module.ai_foundry[0]` should be created.

## If Still Not Working

Share the output of:

```bash
cd infra/terraform

# 1. Check variable evaluation
terraform console -var-file=environments/dev.tfvars <<EOF
var.enable_ai_foundry
var.enable_ai_services
var.enable_storage
var.enable_keyvault
var.enable_ai_foundry && var.enable_ai_services && var.enable_storage && var.enable_keyvault
EOF

# 2. Check plan output
terraform plan -var-file=environments/dev.tfvars 2>&1 | grep -C 3 "ai_foundry"
```

This will help identify which condition is failing.
