# SPDX-License-Identifier: MPL-2.0

export emit_capability_spec

const _CAPABILITY_VERBS = ("GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS")
const _GATEWAY_PATHS = ("/health", "/ready", "/metrics", "/api/v1/minikaran")

function _capability_verb(verb::AbstractString)
    value = uppercase(verb)
    value in _CAPABILITY_VERBS || throw(ArgumentError("Unsupported gateway HTTP verb: $verb"))
    return value
end

# YAML single-quoted scalars have exactly one escape: doubled single quotes.
# Reject line/control characters rather than risk YAML folding or injection.
function _capability_scalar(value::AbstractString)
    any(c -> iscntrl(c) || c in ('\u0085', '\u2028', '\u2029'), value) &&
        throw(ArgumentError("Control/line characters are not supported in capability specs"))
    return "'" * replace(value, "'" => "''") * "'"
end

function _capability_segments(path::String)
    startswith(path, "/") || throw(ArgumentError("Route must start with /: $path"))
    _capability_scalar(path)
    (occursin("//", path) || (path != "/" && endswith(path, "/"))) &&
        throw(ArgumentError("Use canonical routes (no repeated/trailing slash): $path"))
    any(c -> c in ('?', '#', '%', '{', '}') || isspace(c), path) &&
        throw(ArgumentError("Query, fragment, encoded and brace-template routes are unsupported: $path"))
    segments = path == "/" ? String[] : String.(split(path[2:end], '/'))
    names = Set{String}()
    for (i, segment) in enumerate(segments)
        if startswith(segment, ":")
            occursin(r"^:[A-Za-z_][A-Za-z0-9_]*$", segment) ||
                throw(ArgumentError("Invalid route parameter: $segment"))
            segment in names && throw(ArgumentError("Repeated route parameter: $segment"))
            push!(names, segment)
        elseif occursin('*', segment)
            (segment == "*" && i == length(segments)) ||
                throw(ArgumentError("Only a terminal /* wildcard is supported: $path"))
        end
    end
    return segments
end

function _capability_pattern(segments)
    pieces = map(segments) do segment
        startswith(segment, ":") && return "[^/]+"
        segment == "*" && return "[^/]+(?:/[^/]+)*"
        # Escape PCRE metacharacters; route literals are never raw regex.
        return replace(segment, r"[.\\+*?\[\]^$(){}|]" => s"\\\0")
    end
    return "\\A/" * join(pieces, "/") * "\\z"
end

# Upstream regex rules live in an unordered ETS set. Never rely on their
# insertion order to resolve static/parameter/wildcard precedence.
function _capability_overlap(a, b)
    for i in 1:min(length(a), length(b))
        (a[i] == "*" || b[i] == "*") && return true
        if !(startswith(a[i], ":") || startswith(b[i], ":") || a[i] == b[i])
            return false
        end
    end
    return length(a) == length(b)
end

function _capability_annotations(annotations)
    result = Dict{String,String}()
    for annotation in annotations
        startswith(annotation.name, "gateway.") || continue
        annotation.name in ("gateway.exposure", "gateway.capability") ||
            throw(ArgumentError("Unknown gateway annotation: $(annotation.name)"))
        haskey(result, annotation.name) &&
            throw(ArgumentError("Duplicate gateway annotation: $(annotation.name)"))
        isempty(strip(annotation.value)) && throw(ArgumentError("Empty gateway annotation"))
        _capability_scalar(annotation.value)
        result[annotation.name] = annotation.value
    end
    return result
end

"""
    emit_capability_spec(svc::ServiceDescriptor; global_verbs,
                         gateway_profile=:legacy, stealth=true, status_code=404) -> String

Emit deterministic native http-capability-gateway DSL v1 YAML, without dependencies.
`global_verbs` is REQUIRED. The :legacy profile requires explicit nonempty
public globals for compatibility with the unpatched gateway. Use :strict with
an EMPTY list for deny-default on the paired patched gateway. Old gateways reject
that policy at validation/startup, rather than silently granting global verbs.
Neither profile authenticates requests.

Only methods with a nonempty `route_path` are emitted. Verbs on a shared path
are merged. `:parameter` and terminal `/*` are translated to anchored, escaped
PCRE patterns. Ambiguous overlapping routes and gateway-owned paths are rejected.
HEAD/OPTIONS are never inferred. Methods sharing a path must share metadata.

Service annotations supply defaults; method annotations override them:
`gateway.exposure` (public/authenticated/internal), `gateway.capability` (label).
No roles or cryptographic capabilities are inferred from other annotations.
See docs/deployment/docker-compose.adoc for deployment and security limitations.
"""
function emit_capability_spec(svc::ServiceDescriptor; global_verbs::AbstractVector{<:AbstractString},
                              gateway_profile::Symbol=:legacy, stealth::Bool=true, status_code::Integer=404)::String
    # validate_service runs LAST, not first: main's golden copy of it rejects malformed routes
    # with a bare ErrorException, which would preempt the gateway-specific ArgumentError that
    # the capability contract promises callers.
    gateway_profile in (:legacy, :strict) || throw(ArgumentError("Unknown gateway profile"))
    if gateway_profile == :legacy
        isempty(global_verbs) && throw(ArgumentError(
            "Legacy gateway requires nonempty globals; use :strict only with a gateway at or after #112"))
    else
        isempty(global_verbs) || throw(ArgumentError("Strict deny-default profile requires empty global_verbs"))
    end
    globals = sort!(unique(_capability_verb.(global_verbs)))
    status_code in (200, 301, 302, 403, 404, 410, 500, 503) ||
        throw(ArgumentError("Unsupported gateway stealth status code: $status_code"))
    defaults = _capability_annotations(svc.annotations)
    routes = Dict{String,Tuple{Vector{String},Dict{String,String}}}()
    shapes = Dict{String,Vector{String}}()
    for method in svc.methods
        isempty(method.route_path) && continue
        path = method.route_path
        segments = _capability_segments(path)
        verb = _capability_verb(method.http_method)
        metadata = merge(defaults, _capability_annotations(method.annotations))
        get!(metadata, "gateway.exposure", "public")
        metadata["gateway.exposure"] in ("public", "authenticated", "internal") ||
            throw(ArgumentError("Invalid gateway.exposure on $path"))
        if haskey(routes, path)
            verbs, previous = routes[path]
            previous == metadata || throw(ArgumentError("Conflicting gateway annotations on shared path $path"))
            push!(verbs, verb)
        else
            for reserved in _GATEWAY_PATHS
                _capability_overlap(segments, _capability_segments(reserved)) &&
                    throw(ArgumentError("Route overlaps gateway-owned endpoint $reserved: $path"))
            end
            for (other, shape) in shapes
                _capability_overlap(segments, shape) &&
                    throw(ArgumentError("Ambiguous gateway route overlap: $path and $other"))
            end
            shapes[path] = segments
            routes[path] = ([verb], metadata)
        end
    end
    isempty(routes) && throw(ArgumentError("No HTTP-bound methods to emit"))
    validate_service(svc)
    lines = ["# SPDX-License-Identifier: MPL-2.0",
             "# Generated by MaridIR; do not edit. Profile: $gateway_profile.",
             "dsl_version: '1'", "service:",
             "  name: " * _capability_scalar(svc.name),
             "  version: " * _capability_scalar(svc.version),
             "governance:", "  global_verbs: [" * join(globals, ", ") * "]", "  routes:"]
    for path in sort!(collect(keys(routes)))
        verbs, metadata = routes[path]
        push!(lines, "    - path: " * _capability_scalar(_capability_pattern(shapes[path])))
        push!(lines, "      verbs: [" * join(sort!(unique(verbs)), ", ") * "]")
        push!(lines, "      exposure: " * _capability_scalar(metadata["gateway.exposure"]))
        if haskey(metadata, "gateway.capability")
            push!(lines, "      capability: " * _capability_scalar(metadata["gateway.capability"]))
        end
    end
    append!(lines, ["stealth:", "  enabled: $stealth", "  status_code: $status_code"])
    return join(lines, "\n") * "\n"
end
