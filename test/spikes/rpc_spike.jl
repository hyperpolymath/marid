# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# test/spikes/rpc_spike.jl — Gate 1 Disposable JSON-RPC 2.0 & MCP Tool Spike
# Validates JSON-RPC method dispatch, error formatting, and Model Context Protocol schema bindings.

using Test

println("=== MARID-004: JSON-RPC 2.0 & MCP Adapter Spike ===")

# JSON-RPC 2.0 Types
struct JsonRpcRequest
    jsonrpc::String
    method::String
    params::Dict{String, Any}
    id::Union{Int, String, Nothing}
end

struct JsonRpcResponse
    jsonrpc::String
    result::Union{Dict{String, Any}, Nothing}
    error::Union{Dict{String, Any}, Nothing}
    id::Union{Int, String, Nothing}
end

# MCP Tool Definition
struct McpTool
    name::String
    description::String
    input_schema::Dict{String, Any}
end

# Minimal JSON-RPC & MCP Dispatcher
function dispatch_rpc(req::JsonRpcRequest)::JsonRpcResponse
    if req.jsonrpc != "2.0"
        return JsonRpcResponse("2.0", nothing, Dict("code" => -32600, "message" => "Invalid Request"), req.id)
    end
    
    if req.method == "tools/list"
        # MCP tool discovery
        tool = Dict(
            "name" => "reconstruct_phylogenetic_tree",
            "description" => "Runs UPGMA or Neighbor-Joining clustering over biological distance matrices",
            "inputSchema" => Dict("type" => "object", "properties" => Dict("method" => Dict("type" => "string")))
        )
        return JsonRpcResponse("2.0", Dict{String, Any}("tools" => [tool]), nothing, req.id)
        
    elseif req.method == "tools/call"
        tool_name = get(req.params, "name", "")
        if tool_name == "reconstruct_phylogenetic_tree"
            return JsonRpcResponse("2.0", Dict{String, Any}(
                "content" => [Dict("type" => "text", "text" => "Tree reconstructed: ((A:0.1, B:0.2):0.15, C:0.3);")]
            ), nothing, req.id)
        else
            return JsonRpcResponse("2.0", nothing, Dict("code" => -32602, "message" => "Unknown tool: $tool_name"), req.id)
        end
        
    elseif req.method == "relationship/explore"
        # Application service invocation
        return JsonRpcResponse("2.0", Dict{String, Any}("nodes" => 3, "edges" => 2), nothing, req.id)
        
    else
        # Method not found
        return JsonRpcResponse("2.0", nothing, Dict("code" => -32601, "message" => "Method not found"), req.id)
    end
end

# Test 1: JSON-RPC 2.0 Dispatch & Execution
@testset "JSON-RPC 2.0 Dispatch" begin
    req = JsonRpcRequest("2.0", "relationship/explore", Dict("root" => "taxa-1"), 101)
    resp = dispatch_rpc(req)
    
    @test resp.id == 101
    @test resp.error === nothing
    @test resp.result["nodes"] == 3
    println("  [PASS] JSON-RPC standard method call executed successfully")
end

# Test 2: Standard JSON-RPC Error Handling
@testset "JSON-RPC Error Codes" begin
    req_missing = JsonRpcRequest("2.0", "non_existent_method", Dict{String, Any}(), 102)
    resp_err = dispatch_rpc(req_missing)
    
    @test resp_err.id == 102
    @test resp_err.result === nothing
    @test resp_err.error["code"] == -32601
    @test resp_err.error["message"] == "Method not found"
    println("  [PASS] RFC -32601 Method not found properly returned")
end

# Test 3: Model Context Protocol (MCP) Tool Integration
@testset "MCP Tool Discovery & Execution" begin
    # MCP tools/list
    req_list = JsonRpcRequest("2.0", "tools/list", Dict{String, Any}(), 201)
    resp_list = dispatch_rpc(req_list)
    @test haskey(resp_list.result, "tools")
    @test resp_list.result["tools"][1]["name"] == "reconstruct_phylogenetic_tree"
    
    # MCP tools/call
    req_call = JsonRpcRequest("2.0", "tools/call", Dict("name" => "reconstruct_phylogenetic_tree"), 202)
    resp_call = dispatch_rpc(req_call)
    @test occursin("Tree reconstructed", resp_call.result["content"][1]["text"])
    println("  [PASS] MCP tools/list and tools/call protocol contracts validated")
end

println("=== MARID-004 SPIKE PASSED ===")
