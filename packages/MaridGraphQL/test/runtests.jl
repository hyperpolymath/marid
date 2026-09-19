# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridIR
using MaridGraphQL

@testset "MaridGraphQL Tests" begin
    field = FieldDescriptor("id", "ID", nullable=false)
    entity_type = TypeDescriptor("Entity", [field])
    m_get = MethodDescriptor("getEntity", "ID", "Entity", http_method="GET")
    m_create = MethodDescriptor("createEntity", "Entity", "Entity", http_method="POST")
    
    svc = ServiceDescriptor("EntityService", "1.0.0", [entity_type], [m_get, m_create])
    
    sdl = emit_graphql_sdl(svc)
    @test occursin("type Entity {", sdl)
    @test occursin("id: ID!", sdl)
    @test occursin("type Query {", sdl)
    @test occursin("type Mutation {", sdl)
    
    res = execute_graphql_query("{ __schema { queryType { name } } }", svc)
    @test haskey(res, "data")
    @test haskey(res["data"], "__schema")
end
