# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridRPC

@testset "MaridRPC Tests" begin
    registry = Dict{String, Function}(
        "ping" => params -> Dict{String, Any}("pong" => true)
    )
    
    # 1. Success
    req = RpcRequest("2.0", "ping", Dict{String, Any}(), 1)
    res = dispatch_rpc(req, registry)
    @test res.id == 1
    @test res.error === nothing
    @test res.result["pong"] == true
    
    # 2. Method not found
    bad_req = RpcRequest("2.0", "unknownMethod", Dict{String, Any}(), 2)
    bad_res = dispatch_rpc(bad_req, registry)
    @test bad_res.id == 2
    @test bad_res.error["code"] == -32601
end
