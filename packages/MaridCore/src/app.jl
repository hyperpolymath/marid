# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.App

Application container assembling routes, middlewares, and lifecycle states.
"""

export MaridApp, register_route!, dispatch_call

mutable struct MaridApp
    routes::RouteTable{Function}
    middlewares::Vector{Middleware}
    is_ready::Bool
    is_draining::Bool
end

MaridApp() = MaridApp(RouteTable{Function}(), Middleware[], false, false)

function register_route!(app::MaridApp, method::String, path::String, handler::Function)
    app.routes = add_route(app.routes, method, path, handler)
end

function dispatch_call(app::MaridApp, ctx::CallContext, method::String, path::String, input::Stream)
    m = match_route(app.routes, method, path)
    if m === nothing
        throw(NotFoundError("Endpoint", "$method $path"))
    end
    
    pipeline = apply_middleware(app.middlewares, m.handler)
    return pipeline(ctx, (input=input, params=m.params))
end
