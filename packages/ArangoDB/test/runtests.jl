# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using ArangoDB

@testset "ArangoDB Tests" begin
    client = ArangoClient("http://localhost:8529", "testdb", "user", "secret")
    @test occursin("Basic ", format_auth_header(client))
    
    query = ArangoQuery("FOR doc IN collection RETURN doc", Dict{String, Any}(), batch_size=50)
    @test query.batch_size == 50
    
    res = execute_aql(client, query)
    @test res["error"] == false
    @test res["code"] == 201
end
