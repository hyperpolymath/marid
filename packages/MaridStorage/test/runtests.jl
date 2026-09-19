# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridStorage

@testset "MaridStorage Tests" begin
    storage = InMemoryEngine()
    
    # 1. Put & Get
    data = Dict{String, Any}("name" => "Clade A", "support" => 0.98)
    put_entity!(storage, "nodes", "1", data)
    
    retrieved = get_entity(storage, "nodes", "1")
    @test retrieved !== nothing
    @test retrieved["name"] == "Clade A"
    
    # 2. Delete
    delete_entity!(storage, "nodes", "1")
    @test get_entity(storage, "nodes", "1") === nothing
end
