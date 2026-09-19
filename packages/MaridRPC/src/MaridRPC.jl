# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridRPC

JSON-RPC 2.0 and Anthropic Model Context Protocol (MCP) server bindings for Marid.
"""
module MaridRPC

using MaridIR
using MaridCodec

export RpcRequest, RpcResponse, dispatch_rpc

struct RpcRequest
    jsonrpc::String
    method::String
    params::Dict{String, Any}
    id::Union{Int, String, Nothing}
end

struct RpcResponse
    jsonrpc::String
    result::Union{Dict{String, Any}, Nothing}
    error::Union{Dict{String, Any}, Nothing}
    id::Union{Int, String, Nothing}
end

function dispatch_rpc(req::RpcRequest, registry::Dict{String, Function})::RpcResponse
    req.jsonrpc != "2.0" && return RpcResponse("2.0", nothing, Dict("code" => -32600, "message" => "Invalid Request"), req.id)
    
    if haskey(registry, req.method)
        try
            handler = registry[req.method]
            res = handler(req.params)
            return RpcResponse("2.0", res, nothing, req.id)
        catch e
            return RpcResponse("2.0", nothing, Dict("code" => -32603, "message" => "Internal error: $(sprint(showerror, e))"), req.id)
        end
    else
        return RpcResponse("2.0", nothing, Dict("code" => -32601, "message" => "Method not found"), req.id)
    end
end

end # module MaridRPC
