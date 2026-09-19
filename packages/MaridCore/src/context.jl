# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.Context

Immutable request-scoped execution context (`CallContext`) carrying verified principal,
tenant scope, deadline, cooperative cancellation, and distributed trace context.
"""

using UUIDs
using Dates

export CallContext, create_context, is_cancelled, is_expired, check_deadline, cancel!

struct CallContext
    principal::String
    tenant_scope::String
    deadline_ns::UInt64
    cancellation::Base.Event
    trace_id::String
    attributes::Dict{Symbol, Any}
end

"""
    create_context(; principal="anonymous", tenant="default", timeout_ms=30000, trace_id=nothing) -> CallContext

Creates an immutable CallContext with a monotonic deadline and cancellation event.
"""
function create_context(;
    principal::String = "anonymous",
    tenant::String = "default",
    timeout_ms::Int = 30000,
    trace_id::Union{Nothing, String} = nothing,
    attributes::Dict{Symbol, Any} = Dict{Symbol, Any}()
)::CallContext
    delta_ns = Int64(timeout_ms) * 1_000_000
    now = time_ns()
    deadline_ns = if delta_ns >= 0
        now + UInt64(delta_ns)
    else
        abs_delta = UInt64(-delta_ns)
        now > abs_delta ? now - abs_delta : UInt64(0)
    end
    actual_trace_id = trace_id === nothing ? string(uuid4()) : trace_id
    cancellation = Base.Event()
    
    return CallContext(principal, tenant, deadline_ns, cancellation, actual_trace_id, attributes)
end

"""
    is_cancelled(ctx::CallContext) -> Bool

Checks whether the cooperative cancellation event has been notified.
"""
is_cancelled(ctx::CallContext)::Bool = ctx.cancellation.set

"""
    is_expired(ctx::CallContext) -> Bool

Checks whether current monotonic time has passed the deadline.
"""
is_expired(ctx::CallContext)::Bool = time_ns() >= ctx.deadline_ns

"""
    check_deadline(ctx::CallContext)

Throws `TimeoutError` if expired, or returns remaining milliseconds.
"""
function check_deadline(ctx::CallContext)::Float64
    now = time_ns()
    if now >= ctx.deadline_ns
        throw(TimeoutError("Operation exceeded deadline.", Float64(now - ctx.deadline_ns) / 1_000_000))
    end
    return Float64(ctx.deadline_ns - now) / 1_000_000
end

"""
    cancel!(ctx::CallContext)

Triggers the cooperative cancellation signal to stop background work.
"""
function cancel!(ctx::CallContext)
    notify(ctx.cancellation)
end
