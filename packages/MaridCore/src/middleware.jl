# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.Middleware

Streaming middleware chaining: `f(ctx, call, next) -> response`.
"""

export Middleware, FunctionMiddleware, apply_middleware

abstract type Middleware end

struct FunctionMiddleware <: Middleware
    fn::Function
end

"""
    apply_middleware(middlewares::Vector{Middleware}, base_handler::Function) -> Function

Chains middlewares into an executable handler pipeline.
"""
function apply_middleware(middlewares::Vector{<:Middleware}, base_handler::Function)::Function
    pipeline = base_handler
    for mw in reverse(middlewares)
        current_next = pipeline
        current_fn = mw isa FunctionMiddleware ? mw.fn : (ctx, call, next) -> mw(ctx, call, next)
        pipeline = (ctx, call) -> current_fn(ctx, call, current_next)
    end
    return pipeline
end
