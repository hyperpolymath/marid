# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.Errors

RFC 9457 Problem Details and stable domain error hierarchy for Marid.
"""

export MaridError, NotFoundError, ValidationError, UnauthorizedError,
       ConflictError, TimeoutError, InternalError,
       status_code, problem_details

abstract type MaridError <: Exception end

struct NotFoundError <: MaridError
    message::String
    resource::String
    identifier::String
end

NotFoundError(resource::String, id::String) =
    NotFoundError("Resource '$resource' with identifier '$id' not found.", resource, id)

struct ValidationError <: MaridError
    message::String
    field::String
    reason::String
end

struct UnauthorizedError <: MaridError
    message::String
    realm::String
end

UnauthorizedError(msg::String="Unauthorized access.") = UnauthorizedError(msg, "default")

struct ConflictError <: MaridError
    message::String
    resource::String
    revision::String
end

struct TimeoutError <: MaridError
    message::String
    elapsed_ms::Float64
end

struct InternalError <: MaridError
    message::String
    cause::Union{Nothing, Exception}
end

InternalError(msg::String) = InternalError(msg, nothing)

# Status code mappings
status_code(::NotFoundError) = 404
status_code(::ValidationError) = 400
status_code(::UnauthorizedError) = 401
status_code(::ConflictError) = 409
status_code(::TimeoutError) = 504
status_code(::InternalError) = 500
status_code(::MaridError) = 500

# RFC 9457 Problem Details mapping
function problem_details(err::MaridError; instance::String="")::Dict{String, Any}
    Dict{String, Any}(
        "type" => "https://marid.hyperpolymath.org/errors/$(typeof(err))",
        "title" => string(typeof(err)),
        "status" => status_code(err),
        "detail" => err.message,
        "instance" => isempty(instance) ? "/errors/$(typeof(err))" : instance
    )
end
