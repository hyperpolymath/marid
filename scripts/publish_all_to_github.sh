#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# Automation script to create and publish Marid umbrella monorepo and all 18 standalone packages to GitHub.

set -euo pipefail

# --- Defaults ---
ORG="hyperpolymath"
USE_SSH=false
DRY_RUN=false
PUSH_MONOREPO_ONLY=false
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

# --- Usage Banner ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [GITHUB_TOKEN]

Creates and publishes the Marid monorepo and all 18 standalone repositories to GitHub.

Options:
  --org <name>        GitHub organization or username (default: hyperpolymath)
  --token <token>     GitHub Personal Access Token (classic with repo/workflow scope, or fine-grained)
  --ssh               Use SSH (git@github.com:...) instead of HTTPS with token
  --dry-run           Print actions without creating repos or pushing
  --monorepo-only     Only push the umbrella monorepo (marid)
  -h, --help          Show this help message

Authentication:
  - If using HTTPS: GITHUB_TOKEN must be set via --token, env var GITHUB_TOKEN, or positional argument.
  - If using --ssh: Ensure ~/.ssh/id_* has push access to github.com/$ORG.

EOF
  exit 1
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      ORG="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --ssh)
      USE_SSH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --monorepo-only)
      PUSH_MONOREPO_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -z "$TOKEN" && "$1" != -* ]]; then
        TOKEN="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        usage
      fi
      ;;
  esac
done

if [[ "$USE_SSH" == false && -z "$TOKEN" && "$DRY_RUN" == false ]]; then
  echo "Error: Either GITHUB_TOKEN must be provided or --ssh must be specified." >&2
  echo "Run with --help for usage details." >&2
  exit 1
fi

echo "================================================================="
echo "  Marid GitHub Publishing Suite"
echo "  Target Organization / Account : $ORG"
echo "  Protocol                      : $( [ "$USE_SSH" = true ] && echo "SSH (git@github.com)" || echo "HTTPS (token authenticated)" )"
echo "  Dry Run                       : $DRY_RUN"
echo "================================================================="
echo

# Helper: Create GitHub Repository via REST API if it doesn't already exist
create_github_repo() {
  local repo_name="$1"
  local desc="$2"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would create GitHub repo: $ORG/$repo_name (\"$desc\")"
    return 0
  fi

  if [ -z "$TOKEN" ]; then
    echo "[INFO] No GITHUB_TOKEN provided; skipping remote API repo creation for $repo_name (assuming repo already exists on GitHub)."
    return 0
  fi

  echo -n "[GitHub API] Checking/creating repository $ORG/$repo_name... "

  # Check if repository already exists
  local status_code
  status_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$ORG/$repo_name")

  if [ "$status_code" -eq 200 ]; then
    echo "already exists (HTTP 200)."
    return 0
  fi

  # Attempt creation under organization first
  local create_response
  create_response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$ORG/repos" \
    -d "{\"name\": \"$repo_name\", \"description\": \"$desc\", \"private\": false, \"has_issues\": true, \"has_projects\": false, \"has_wiki\": false}")

  local http_code
  http_code=$(echo "$create_response" | tail -n1)

  if [ "$http_code" -eq 201 ]; then
    echo "created successfully (HTTP 201)."
  elif [ "$http_code" -eq 404 ]; then
    # If orgs endpoint returns 404, ORG might be a user account instead of an organization
    local user_response
    user_response=$(curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/user/repos" \
      -d "{\"name\": \"$repo_name\", \"description\": \"$desc\", \"private\": false, \"has_issues\": true}")
    local user_code
    user_code=$(echo "$user_response" | tail -n1)
    if [ "$user_code" -eq 201 ]; then
      echo "created under user account (HTTP 201)."
    else
      echo "failed (HTTP $user_code). Details: $(echo "$user_response" | head -n -1)"
    fi
  else
    echo "response code HTTP $http_code: $(echo "$create_response" | head -n -1)"
  fi
}

# Helper: Configure remote URL and push main branch
push_repo() {
  local dir_path="$1"
  local repo_name="$2"

  if [ ! -d "$dir_path/.git" ]; then
    echo "[ERROR] Directory $dir_path is not a valid git repository!" >&2
    return 1
  fi

  local remote_url
  if [ "$USE_SSH" = true ]; then
    remote_url="git@github.com:${ORG}/${repo_name}.git"
  else
    remote_url="https://x-access-token:${TOKEN}@github.com/${ORG}/${repo_name}.git"
  fi

  echo "===> [$repo_name] Setting remote and pushing to $ORG/$repo_name..."

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] git -C \"$dir_path\" remote add/set-url origin \"$remote_url\""
    echo "[DRY RUN] git -C \"$dir_path\" push -u origin main"
    return 0
  fi

  # Set origin URL
  if git -C "$dir_path" remote get-url origin >/dev/null 2>&1; then
    git -C "$dir_path" remote set-url origin "$remote_url"
  else
    git -C "$dir_path" remote add origin "$remote_url"
  fi

  # Push to GitHub
  git -C "$dir_path" push -u origin main
  echo "[SUCCESS] $repo_name pushed cleanly to GitHub."
  echo
}

# =====================================================================
# 1. Push Umbrella Monorepo (marid)
# =====================================================================
echo "--- Step 1: Umbrella Monorepo (marid) ---"
MONOREPO_DIR="/home/user/marid"
if [ -d "$MONOREPO_DIR" ]; then
  create_github_repo "marid" "Production-grade, polyglot microservice framework written in Julia"
  push_repo "$MONOREPO_DIR" "marid"
else
  echo "[WARN] Monorepo not found at $MONOREPO_DIR"
fi

if [ "$PUSH_MONOREPO_ONLY" = true ]; then
  echo "Monorepo push complete (--monorepo-only set). Exiting."
  exit 0
fi

# =====================================================================
# 2. Push Standalone Repositories
# =====================================================================
echo "--- Step 2: Standalone Repositories ---"

# Format: "local_dir:github_repo_name:description"
standalone_repos=(
  # Julia Packages
  "/home/user/MaridIR.jl:MaridIR.jl:Declarative Intermediate Representation and Code Generator for Marid service architectures"
  "/home/user/MaridCore.jl:MaridCore.jl:Kernel engine, runtime dispatch, and lifecycle control for Marid service architectures"
  "/home/user/ArangoDB.jl:ArangoDB.jl:Pure Julia high-performance client driver for ArangoDB multi-model graph and document database"
  "/home/user/MaridCodec.jl:MaridCodec.jl:Optimized serialization, deserialization, and schema validation codecs for Marid"
  "/home/user/MaridOpenAPI.jl:MaridOpenAPI.jl:OpenAPI 3.1 schema and interactive documentation generator for Marid service specs"
  "/home/user/MaridRPC.jl:MaridRPC.jl:JSON-RPC 2.0 and high-performance RPC dispatch engine for Marid service architectures"
  "/home/user/MaridGraphQL.jl:MaridGraphQL.jl:Declarative GraphQL schema compiler, type registry, and query executor for Marid"
  "/home/user/MaridTransport.jl:MaridTransport.jl:High-throughput asynchronous HTTP/1.1, HTTP/2, and WebSocket transport engine for Marid"
  "/home/user/MaridStorage.jl:MaridStorage.jl:Abstract repository and multi-backend persistence engine for Marid service architectures"
  "/home/user/MaridControl.jl:MaridControl.jl:Observability, health probes, circuit breakers, rate limiters, and telemetry for Marid"
  "/home/user/MaridLive.jl:MaridLive.jl:Real-time reactive pub/sub, Server-Sent Events (SSE), and bidirectional live channels for Marid"
  "/home/user/MaridCRDT.jl:MaridCRDT.jl:Conflict-free Replicated Data Types (state-based CRDTs) for distributed state replication"
  "/home/user/MaridRaft.jl:MaridRaft.jl:Pure Julia Raft distributed consensus protocol implementation for Marid clusters"
  # Web Packages
  "/home/user/marid-client:marid-client:Lightweight TypeScript / ES module browser client SDK for Marid service architectures"
  "/home/user/marid-elements:marid-elements:Autonomous standard Web Components library for Marid reactive interfaces"
  "/home/user/marid-react:marid-react:Idiomatic React hooks and component bindings for Marid reactive clients"
  "/home/user/marid-vue:marid-vue:Idiomatic Vue 3 composables and component bindings for Marid reactive clients"
  # Reference Application
  "/home/user/relationship_explorer:marid-relationship-explorer:Reference application demonstrating end-to-end full-stack Marid reactive graph architecture"
)

for entry in "${standalone_repos[@]}"; do
  IFS=":" read -r local_dir github_repo desc <<< "$entry"
  if [ -d "$local_dir" ]; then
    echo "-----------------------------------------------------------------"
    create_github_repo "$github_repo" "$desc"
    push_repo "$local_dir" "$github_repo"
  else
    echo "[WARN] Directory not found: $local_dir"
  fi
done

echo "================================================================="
echo "  All repositories processed successfully!"
echo "================================================================="
