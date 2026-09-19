# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using ArangoDB

@testset "ArangoDB Full Integration Suite" begin
    client = ArangoClient("http://127.0.0.1:8529", "biomodel_test", username="root", password="dev")
    
    # 1. Document Creation & Retrieval
    @testset "Document CRUD" begin
        doc = Dict{String, Any}("name" => "Pan troglodytes", "clade" => "Hominidae", "extinct" => false)
        res = create_document(client, "species", doc, return_new=true)
        
        @test haskey(res, "_key")
        @test haskey(res, "_rev")
        @test res["new"]["name"] == "Pan troglodytes"
        
        key = res["_key"]
        rev = res["_rev"]
        
        # Read back
        read_doc = get_document(client, "species", key)
        @test read_doc["name"] == "Pan troglodytes"
        
        # Revision mismatch test
        @test_throws ArangoError get_document(client, "species", key, rev="wrong_rev")
        
        # Update with revision checking
        update_doc = Dict{String, Any}("extinct" => true, "_rev" => rev)
        up_res = update_document(client, "species", key, update_doc, check_rev=true)
        @test up_res["_oldRev"] == rev
        @test up_res["_rev"] != rev
        
        # Conflict on stale revision
        stale_update = Dict{String, Any}("extinct" => false, "_rev" => rev)
        @test_throws ArangoError update_document(client, "species", key, stale_update, check_rev=true)
        
        # Delete
        del_res = delete_document(client, "species", key)
        @test del_res["_key"] == key
        @test_throws ArangoError get_document(client, "species", key)
    end
    
    # 2. Edge Collections
    @testset "Edge Connections" begin
        n1 = create_document(client, "nodes", Dict{String, Any}("name" => "Clade A"))
        n2 = create_document(client, "nodes", Dict{String, Any}("name" => "Clade B"))
        
        edge = create_edge(client, "edges", n1["_id"], n2["_id"], Dict{String, Any}("weight" => 0.85))
        @test occursin("nodes/", edge["_key"]) == false
        
        read_edge = get_document(client, "edges", edge["_key"])
        @test read_edge["_from"] == n1["_id"]
        @test read_edge["_to"] == n2["_id"]
        @test read_edge["weight"] == 0.85
    end
    
    # 3. AQL Cursors & Pagination
    @testset "AQL Query Cursors" begin
        # Seed test items
        for i in 1:15
            create_document(client, "bulk_items", Dict{String, Any}("val" => i))
        end
        
        query = ArangoQuery("FOR item IN bulk_items RETURN item", batch_size=5)
        cursor = create_cursor(client, query)
        
        @test cursor.has_more == true
        @test length(cursor.batch) == 5
        
        # Fetch next batch
        b2 = next_batch(cursor)
        @test length(b2) > 0
        
        # Delete cursor
        delete_cursor(cursor)
        @test cursor.id === nothing
        @test cursor.has_more == false
    end
    
    # 4. Stream Transactions
    @testset "Transactions" begin
        tx_id = begin_transaction(client, ["species", "edges"])
        @test occursin("tx_", tx_id)
        @test commit_transaction(client, tx_id) == true
        
        tx_id2 = begin_transaction(client, ["species"])
        @test abort_transaction(client, tx_id2) == true
    end
end
