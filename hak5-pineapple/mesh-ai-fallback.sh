#!/bin/bash
# Mesh Network AI Fallback Configuration
# Routes requests through your mesh network if primary services fail

MESH_NODES=(
  "http://localhost:11434"      # Primary Ollama
  "http://localhost:3080"       # Primary Lab
)

BACKUP_NODES=(
  # Add your mesh network nodes here if available
  # "http://mesh-node-1:11434"
  # "http://mesh-node-2:3080"
)

# Test and route function
route_to_available() {
  local endpoint=$1
  local test_path=$2
  
  # Test primary nodes first
  for node in "${MESH_NODES[@]}"; do
    if curl -s -m 2 "${node}${test_path}" > /dev/null 2>&1; then
      echo "$node"
      return 0
    fi
  done
  
  # Fall back to backup mesh nodes
  for node in "${BACKUP_NODES[@]}"; do
    if curl -s -m 2 "${node}${test_path}" > /dev/null 2>&1; then
      echo "$node"
      return 0
    fi
  done
  
  echo "UNAVAILABLE"
  return 1
}

# Get current AI endpoint
get_ai_endpoint() {
  local endpoint=$(route_to_available "ollama" "/api/tags")
  if [[ "$endpoint" != "UNAVAILABLE" ]]; then
    echo "$endpoint"
  else
    echo "ERROR: No AI services available"
    return 1
  fi
}

# Get current lab endpoint
get_lab_endpoint() {
  local endpoint=$(route_to_available "lab" "/")
  if [[ "$endpoint" != "UNAVAILABLE" ]]; then
    echo "$endpoint"
  else
    echo "ERROR: No lab services available"
    return 1
  fi
}

# Health check all nodes
health_check() {
  echo "🔍 Checking AI network health..."
  echo ""
  
  for node in "${MESH_NODES[@]}" "${BACKUP_NODES[@]}"; do
    if curl -s -m 2 "$node/api/tags" > /dev/null 2>&1; then
      echo "✅ $node - ONLINE"
    else
      echo "❌ $node - OFFLINE"
    fi
  done
}

# Export functions for use in other scripts
export -f route_to_available
export -f get_ai_endpoint
export -f get_lab_endpoint
export -f health_check

# If called directly, run health check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  health_check
fi
