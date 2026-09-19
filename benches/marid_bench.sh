#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Marid Framework Performance Benchmarks
# Measures IR generation throughput, router dispatch latency, and emitter efficiency.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARID_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$MARID_ROOT"

OUTPUT_FORMAT="${1:-human}" # human | json | csv

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  MARID — Framework & IR Emitter Benchmarks                                    ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}→${NC} Running MaridIR Emitter benchmarks (10,000 iterations)..."

JULIA_BENCH_OUT=$(julia --project=packages/MaridIR -e '
    using MaridIR

    f_id = FieldDescriptor("id", "String")
    f_name = FieldDescriptor("name", "String")
    f_rank = FieldDescriptor("rank", "String")
    t_taxon = TypeDescriptor("Taxon", [f_id, f_name, f_rank])

    m_list = MethodDescriptor("listTaxa", "Void", "Taxon", streaming=ServerStreaming,
                              route_path="/api/v1/taxa", http_method="GET",
                              description="List all taxa",
                              annotations=[Annotation("capability", "taxa:read")])
    m_get = MethodDescriptor("getTaxon", "String", "Taxon", streaming=Unary,
                             route_path="/api/v1/taxa/:id", http_method="GET",
                             description="Get taxon by ID",
                             annotations=[Annotation("capability", "taxa:read"), Annotation("exposure", "authenticated")])
    m_del = MethodDescriptor("deleteTaxon", "String", "Void", streaming=Unary,
                             route_path="/api/v1/taxa/:id", http_method="DELETE",
                             description="Delete taxon",
                             annotations=[Annotation("capability", "taxa:admin")])
    m_create = MethodDescriptor("createTaxon", "Taxon", "Taxon", streaming=Unary,
                                route_path="/api/v1/taxa", http_method="POST",
                                description="Create taxon")

    svc = ServiceDescriptor("TaxonomyService", "1.0.0", [t_taxon], [m_list, m_get, m_del, m_create])

    # Warmup
    for _ in 1:200
        emit_capability_spec(svc)
        emit_proto(svc)
        validate_service(svc)
    end

    N = 10_000

    # 1. Capability Spec Emitter
    t0 = time_ns()
    for _ in 1:N
        emit_capability_spec(svc)
    end
    t1 = time_ns()
    cap_ms = (t1 - t0) / 1e6
    cap_us = (cap_ms * 1000) / N
    cap_ops = N / ((t1 - t0) / 1e9)

    # 2. Proto Emitter
    t0 = time_ns()
    for _ in 1:N
        emit_proto(svc)
    end
    t1 = time_ns()
    proto_ms = (t1 - t0) / 1e6
    proto_us = (proto_ms * 1000) / N
    proto_ops = N / ((t1 - t0) / 1e9)

    # 3. IR Validation
    t0 = time_ns()
    for _ in 1:N
        validate_service(svc)
    end
    t1 = time_ns()
    val_ms = (t1 - t0) / 1e6
    val_us = (val_ms * 1000) / N
    val_ops = N / ((t1 - t0) / 1e9)

    println("CAP_US=$(round(cap_us, digits=2))")
    println("CAP_OPS=$(round(Int, cap_ops))")
    println("PROTO_US=$(round(proto_us, digits=2))")
    println("PROTO_OPS=$(round(Int, proto_ops))")
    println("VAL_US=$(round(val_us, digits=2))")
    println("VAL_OPS=$(round(Int, val_ops))")
')

eval "$JULIA_BENCH_OUT"

echo -e "${GREEN}✓${NC} http-capability-gateway Spec Emitter: ${CAP_US} µs/op (${CAP_OPS} ops/sec)"
echo -e "${GREEN}✓${NC} Protobuf v3 Schema Emitter:            ${PROTO_US} µs/op (${PROTO_OPS} ops/sec)"
echo -e "${GREEN}✓${NC} ServiceDescriptor Validation:          ${VAL_US} µs/op (${VAL_OPS} ops/sec)"

# CLI Emitter Benchmark
echo -e "${BLUE}→${NC} Benchmarking CLI 'marid generate capability-spec' latency..."
START_CLI=$(date +%s%N)
./scripts/marid generate capability-spec /tmp/sample_service.jl > /dev/null
END_CLI=$(date +%s%N)
CLI_LATENCY_MS=$(( (END_CLI - START_CLI) / 1000000 ))
echo -e "${GREEN}✓${NC} CLI Cold Invocation Latency:           ${CLI_LATENCY_MS} ms"

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  BENCHMARK SUMMARY                                                            ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"

if [ "$OUTPUT_FORMAT" = "json" ]; then
    cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "capability_spec_emitter_us": $CAP_US,
    "capability_spec_emitter_ops_sec": $CAP_OPS,
    "proto_emitter_us": $PROTO_US,
    "proto_emitter_ops_sec": $PROTO_OPS,
    "ir_validation_us": $VAL_US,
    "ir_validation_ops_sec": $VAL_OPS,
    "cli_invocation_ms": $CLI_LATENCY_MS
  }
}
EOF
elif [ "$OUTPUT_FORMAT" = "csv" ]; then
    cat <<EOF
metric,value,unit,timestamp
capability_spec_emitter,$CAP_US,us,$(date -u +%Y-%m-%dT%H:%M:%SZ)
proto_emitter,$PROTO_US,us,$(date -u +%Y-%m-%dT%H:%M:%SZ)
ir_validation,$VAL_US,us,$(date -u +%Y-%m-%dT%H:%M:%SZ)
cli_invocation,$CLI_LATENCY_MS,ms,$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
else
    printf "  %-36s %8s µs/op  (%d ops/sec)\n" "http-capability-gateway spec emitter:" "$CAP_US" "$CAP_OPS"
    printf "  %-36s %8s µs/op  (%d ops/sec)\n" "Protobuf schema emitter:" "$PROTO_US" "$PROTO_OPS"
    printf "  %-36s %8s µs/op  (%d ops/sec)\n" "ServiceDescriptor validation:" "$VAL_US" "$VAL_OPS"
    printf "  %-36s %8d ms\n" "CLI generator invocation:" "$CLI_LATENCY_MS"
fi

echo ""
echo "Benchmarks passed successfully."
