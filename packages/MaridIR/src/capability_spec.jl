# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridIR.CapabilitySpec

Generator emitting http-capability-gateway Verb Governance Spec (DSL v1) from `ServiceDescriptor`.
Ensures zero contract drift between Marid services and http-capability-gateway perimeter enforcement.
"""

export emit_capability_spec

# Valid HTTP verbs recognized by http-capability-gateway
const VALID_GATEWAY_VERBS = Set(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])

function _normalize_route_pattern(route_path::String, default_name::String)::String
    p = isempty(strip(route_path)) ? "/$default_name" : strip(route_path)
    # Convert Express-style :param to regex [^/]+
    p = replace(p, r":([a-zA-Z0-9_]+)" => "[^/]+")
    # Convert OpenAPI-style {param} to regex [^/]+
    p = replace(p, r"\{([a-zA-Z0-9_]+)\}" => "[^/]+")
    # Anchor pattern if not already anchored
    prefix = startswith(p, "^") ? "" : "^"
    suffix = endswith(p, "\$") ? "" : "\$"
    return "$(prefix)$(p)$(suffix)"
end

function _find_annotation(annotations::Vector{Annotation}, key::String, default::Union{String, Nothing}=nothing)::Union{String, Nothing}
    for a in annotations
        if lowercase(a.name) == lowercase(key)
            return a.value
        end
    end
    return default
end

"""
    emit_capability_spec(svc;
                         global_verbs::Vector{String}=["GET", "POST"],
                         stealth_enabled::Bool=true,
                         stealth_status::Int=404)::String

Emits a declarative http-capability-gateway Verb Governance Spec (DSL v1) in YAML format
from a `MaridIR.ServiceDescriptor`.
"""
function emit_capability_spec(svc::Any;
                              global_verbs::Vector{String}=["GET", "POST"],
                              stealth_enabled::Bool=true,
                              stealth_status::Int=404)::String
    # Validate global verbs
    for v in global_verbs
        uv = uppercase(v)
        !(uv in VALID_GATEWAY_VERBS) && error("Invalid global HTTP verb '$v'. Valid verbs: $(sort(collect(VALID_GATEWAY_VERBS)))")
    end

    if stealth_status < 100 || stealth_status > 599
        error("Invalid stealth status code: $stealth_status. Must be between 100 and 599.")
    end

    lines = String[]
    push!(lines, "# SPDX-License-Identifier: MPL-2.0")
    push!(lines, "# http-capability-gateway Verb Governance Spec (DSL v1)")
    push!(lines, "# Generated automatically by MaridIR for $(svc.name) (v$(svc.version))")
    push!(lines, "")
    push!(lines, "dsl_version: \"1\"")
    push!(lines, "")
    push!(lines, "governance:")
    push!(lines, "  global_verbs:")
    for v in global_verbs
        push!(lines, "    - $(uppercase(v))")
    end
    push!(lines, "")

    if !isempty(svc.methods)
        push!(lines, "  routes:")

        # Group methods by normalized path pattern preserving order
        ordered_patterns = String[]
        grouped_methods = Dict{String, Vector{MethodDescriptor}}()

        for m in svc.methods
            pattern = _normalize_route_pattern(m.route_path, m.name)
            if !haskey(grouped_methods, pattern)
                push!(ordered_patterns, pattern)
                grouped_methods[pattern] = MethodDescriptor[]
            end
            push!(grouped_methods[pattern], m)
        end

        for pattern in ordered_patterns
            methods = grouped_methods[pattern]
            verbs = String[]
            capabilities = String[]
            narratives = String[]
            exposures = String[]

            for m in methods
                verb = uppercase(m.http_method)
                !(verb in VALID_GATEWAY_VERBS) && error("Invalid HTTP verb '$verb' in method '$(m.name)'")
                if !(verb in verbs)
                    push!(verbs, verb)
                end

                # Check annotations for capability, narrative, exposure
                cap = _find_annotation(m.annotations, "capability", "$(svc.name).$(m.name)")
                if cap !== nothing && !isempty(cap) && !(cap in capabilities)
                    push!(capabilities, cap)
                end

                nar = _find_annotation(m.annotations, "narrative", isempty(m.description) ? nothing : m.description)
                if nar !== nothing && !isempty(nar) && !(nar in narratives)
                    push!(narratives, nar)
                end

                exp = _find_annotation(m.annotations, "exposure", nothing)
                if exp !== nothing && !isempty(exp) && !(exp in exposures)
                    push!(exposures, exp)
                end
            end

            push!(lines, "    - path: \"$pattern\"")
            push!(lines, "      verbs:")
            for v in verbs
                push!(lines, "        - $v")
            end

            if !isempty(capabilities)
                push!(lines, "      capability: \"$(join(capabilities, ", "))\"")
            end

            if !isempty(narratives)
                # Escape quotes if necessary
                escaped_nar = replace(join(narratives, "; "), "\"" => "\\\"")
                push!(lines, "      narrative: \"$escaped_nar\"")
            end

            if !isempty(exposures)
                push!(lines, "      exposure: $(exposures[1])")
            end
        end
    else
        push!(lines, "  routes: []")
    end

    push!(lines, "")
    push!(lines, "stealth:")
    push!(lines, "  enabled: $(stealth_enabled ? "true" : "false")")
    push!(lines, "  status_code: $stealth_status")

    return join(lines, "\n") * "\n"
end
