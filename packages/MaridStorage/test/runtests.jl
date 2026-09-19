# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridStorage

@testset "MaridStorage Suite" begin
    # 1. In-Memory Engine
    @testset "InMemoryEngine Operations" begin
        storage = InMemoryEngine()
        data = Dict{String, Any}("name" => "Clade A", "support" => 0.98)
        put_entity!(storage, "nodes", "1", data)
        
        retrieved = get_entity(storage, "nodes", "1")
        @test retrieved !== nothing
        @test retrieved["name"] == "Clade A"
        @test retrieved["_id"] == "nodes/1"
        
        # Querying
        put_entity!(storage, "nodes", "2", Dict{String, Any}("name" => "Clade B", "support" => 0.85))
        all_nodes = query_entities(storage, "nodes")
        @test length(all_nodes) == 2
        
        high_support = query_entities(storage, "nodes", filter_fn = n -> n["support"] > 0.9)
        @test length(high_support) == 1
        @test high_support[1]["name"] == "Clade A"
        
        delete_entity!(storage, "nodes", "1")
        @test get_entity(storage, "nodes", "1") === nothing
    end

    # 2. ArangoDB Storage Engine Seam
    @testset "ArangoStorageEngine Seam" begin
        arango_storage = ArangoStorageEngine("http://127.0.0.1:8529", "biomodel_test")
        edge_data = Dict{String, Any}("_from" => "nodes/1", "_to" => "nodes/2", "weight" => 0.99)
        put_entity!(arango_storage, "edges", "e1", edge_data)
        
        e = get_entity(arango_storage, "edges", "e1")
        @test e !== nothing
        @test e["weight"] == 0.99
    end
end
