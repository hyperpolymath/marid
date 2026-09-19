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


export bind_service!, serve_json

# Implemented only when the optional Codec and Transport packages are loaded.
function serve_json end

"""
    bind_service!(app, service, handlers)

Atomically install HTTP-bound unary methods from one validated IR descriptor.
Handlers are keyed by IR method name and use the existing (context, call) stream
contract. All bindings are checked before changing the app's route table.
"""
function bind_service!(app::MaridApp, service::ServiceDescriptor, handlers::AbstractDict)
    validate_service(service)
    table = app.routes
    for method in service.methods
        isempty(method.route_path) && continue
        method.streaming == Unary || throw(ArgumentError("HTTP JSON slice supports unary methods only"))
        haskey(handlers, method.name) || throw(ArgumentError("Missing handler: $(method.name)"))
        handler = handlers[method.name]
        handler isa Function || throw(ArgumentError("Handler must be a function: $(method.name)"))
        table = add_route(table, method.http_method, method.route_path, handler)
    end
    app.routes = table
    return app
end
