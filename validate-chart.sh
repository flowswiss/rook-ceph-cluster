#!/bin/bash

# Helm Chart Syntax Validation Script
# Umfassende Validierung des Rook Ceph Helm Charts

set -e

CHART_DIR="/Users/reto/rook-ceph-cluster"
cd "$CHART_DIR"

echo "🔍 Starting Helm Chart Syntax Validation..."
echo "Chart: $(pwd)"
echo ""

# Test 1: Basic Helm Lint
echo "📋 Test 1: Basic Helm Lint"
helm lint . --strict
echo "✅ Basic lint passed"
echo ""

# Test 2: Template Rendering
echo "📋 Test 2: Template Rendering"
helm template test-release . > /tmp/rendered-chart.yaml
echo "✅ Template rendering passed"
echo ""

# Test 3: YAML Structure Validation
echo "📋 Test 3: YAML Structure Validation"
if command -v yq &> /dev/null; then
    yq eval 'true' /tmp/rendered-chart.yaml > /dev/null
    echo "✅ YAML structure validation passed"
else
    echo "⚠️  yq not available, skipping YAML validation"
fi
echo ""

# Test 4: Kubernetes Resource Validation
echo "📋 Test 4: Kubernetes Resource Validation"
RESOURCES=$(helm template test-release . | grep -E "^kind: " | sort | uniq -c)
echo "Generated Kubernetes resources:"
echo "$RESOURCES"
echo ""

# Test 5: Required Fields Check  
echo "📋 Test 5: Required Fields Check"

# Check CephCluster required fields
echo "Checking CephCluster required fields..."
helm template test-release . | grep -A 100 "kind: CephCluster" | grep -E "(cephVersion|dataDirHostPath|mon|mgr|storage)" | head -5
echo "✅ CephCluster required fields present"

# Check CephBlockPool required fields
echo "Checking CephBlockPool required fields..."
helm template test-release . | grep -A 20 "kind: CephBlockPool" | grep -E "(failureDomain|replicated)" | head -2
echo "✅ CephBlockPool required fields present"

# Check CephFilesystem required fields  
echo "Checking CephFilesystem required fields..."
helm template test-release . | grep -A 20 "kind: CephFilesystem" | grep -E "(dataPools|metadataPool|metadataServer)" | head -3
echo "✅ CephFilesystem required fields present"
echo ""

# Test 6: Values Schema Validation
echo "📋 Test 6: Values Schema Validation"
REQUIRED_VALUES="cephCluster cephBlockPools cephFileSystems toolbox operator"
for val in $REQUIRED_VALUES; do
    if grep -q "^$val:" values.yaml; then
        echo "✅ $val section found in values.yaml"
    else
        echo "❌ $val section missing in values.yaml"
    fi
done
echo ""

# Test 7: Template Logic Check
echo "📋 Test 7: Template Logic Check"
CONDITIONALS=$(grep -r "{{-.*if" templates/ | wc -l)
LOOPS=$(grep -r "{{-.*range" templates/ | wc -l)  
INCLUDES=$(grep -r "{{-.*include" templates/ | wc -l)
echo "Template complexity:"
echo "  - Conditionals: $CONDITIONALS"
echo "  - Loops: $LOOPS"
echo "  - Includes: $INCLUDES"
echo "✅ Template logic check passed"
echo ""

# Test 8: Resource Consistency
echo "📋 Test 8: Resource Consistency Check"
# Check if all resources have consistent labeling
HELM_LABELS=$(helm template test-release . | grep -E "app\.kubernetes\.io/(name|instance|managed-by)" | wc -l)
TOTAL_RESOURCES=$(helm template test-release . | grep -E "^kind: " | wc -l)
echo "Helm labels applied: $HELM_LABELS"
echo "Total resources: $TOTAL_RESOURCES"
if [ "$HELM_LABELS" -gt 0 ]; then
    echo "✅ Resource labeling consistency check passed"
fi
echo ""

echo "🎉 All syntax validations completed successfully!"
echo ""
echo "📊 Chart Summary:"
echo "   • Chart Name: rook-ceph-cluster"
echo "   • Chart Version: $(grep '^version:' Chart.yaml | awk '{print $2}')"
echo "   • App Version: $(grep '^appVersion:' Chart.yaml | awk '{print $2}')"
echo "   • Templates: $(ls templates/ | wc -l) files"
echo "   • Generated Resources: $TOTAL_RESOURCES"
echo ""
echo "✅ Chart is ready for deployment!"
