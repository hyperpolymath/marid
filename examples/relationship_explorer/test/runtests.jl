# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
include(joinpath(@__DIR__, "..", "src", "RelationshipExplorer.jl"))
using .RelationshipExplorer
using MaridCore
using MaridIR
using MaridStorage
using MaridGraphQL
using MaridOpenAPI

@testset "Relationship Explorer Integration Suite" begin
    # 1. Domain Service & Storage
    @testset "Entity CRUD & Relationships" begin
        svc = TaxonService()
        t1 = create_taxon!(svc, "Homo sapiens", "Species", [1, 1, 1, 1, 1])
        t2 = create_taxon!(svc, "Pan troglodytes", "Species", [1, 1, 0, 0, 0])
        t3 = create_taxon!(svc, "Hylobates lar", "Species", [1, 1, 0, 0, 0])
        
        @test t1.id == "taxon_1"
        @test get_taxon(svc, "taxon_1").name == "Homo sapiens"
        @test length(list_taxa(svc)) == 3
        
        # Link taxa
        rel1 = create_relationship!(svc, t1.id, t2.id, "sister_to", 0.95)
        rel2 = create_relationship!(svc, t2.id, t3.id, "sister_to", 0.80)
        @test rel1.from_id == "taxon_1"
        @test rel1.to_id == "taxon_2"
    end

    # 2. Bounded Neighborhood Exploration
    @testset "Neighborhood Graph Traversal" begin
        svc = TaxonService()
        t1 = create_taxon!(svc, "Homo sapiens", "Species", [1, 1, 1, 1, 1])
        t2 = create_taxon!(svc, "Pan troglodytes", "Species", [1, 1, 0, 0, 0])
        t3 = create_taxon!(svc, "Lemur catta", "Species", [1, 0, 0, 0, 0])
        
        create_relationship!(svc, t1.id, t2.id, "sister_to")
        create_relationship!(svc, t2.id, t3.id, "ancestral")
        
        # Depth 1 neighborhood from t1 includes t1 and t2
        nh1 = get_neighborhood(svc, t1.id, 1)
        @test length(nh1.nodes) == 2
        @test length(nh1.edges) == 1
        
        # Depth 2 neighborhood from t1 includes t1, t2, and t3
        nh2 = get_neighborhood(svc, t1.id, 2)
        @test length(nh2.nodes) == 3
        @test length(nh2.edges) == 2
    end

    # 3. Cladistics Analysis & Progress Streaming
    @testset "Cladistics Analysis & Streaming Progress" begin
        svc = TaxonService()
        t1 = create_taxon!(svc, "Homo sapiens", "Species", [1, 1, 1, 1, 1])
        t2 = create_taxon!(svc, "Pan troglodytes", "Species", [1, 1, 0, 0, 0])
        
        progress_steps = AnalysisProgress[]
        result = execute_analysis(svc, [t1.id, t2.id], on_progress = (p) -> push!(progress_steps, p))
        
        @test length(progress_steps) == 4
        @test progress_steps[end].stage == "Complete"
        @test occursin("Homo sapiens", result.tree_newick)
        @test occursin("Pan troglodytes", result.tree_newick)
        @test result.parsimony_score > 0
    end

    # 4. Multi-Protocol MaridApp Dispatch
    @testset "Multi-Protocol App Dispatch" begin
        svc = TaxonService()
        create_taxon!(svc, "Gorilla gorilla", "Species", [1, 1, 0, 0, 0])
        app = build_app(svc)
        ctx = create_context(principal="biologist_1")
        
        # Test GET /api/v1/taxa
        in_stream = Stream{String}(ctx)
        out_stream = dispatch_call(app, ctx, "GET", "/api/v1/taxa", in_stream)
        items = collect_stream(out_stream)
        @test length(items) == 1
        @test items[1]["name"] == "Gorilla gorilla"
        
        # Test GET /api/v1/taxa/:id
        out_single = dispatch_call(app, ctx, "GET", "/api/v1/taxa/taxon_1", in_stream)
        single_item = collect_stream(out_single)
        @test single_item[1]["name"] == "Gorilla gorilla"
        
        # Test POST /api/v1/analysis (streaming response)
        out_analysis = dispatch_call(app, ctx, "POST", "/api/v1/analysis", in_stream)
        analysis_frames = collect_stream(out_analysis)
        @test length(analysis_frames) >= 2 # at least one progress and one result frame
        @test any(f -> f["type"] == "progress", analysis_frames)
        @test any(f -> f["type"] == "result", analysis_frames)
        
        # Test Bebop & Cap'n Proto export endpoints
        out_bop = dispatch_call(app, ctx, "GET", "/api/v1/export/bebop", in_stream)
        bop_data = collect_stream(out_bop)
        @test bop_data[1]["format"] == "bebop"
        
        out_capnp = dispatch_call(app, ctx, "GET", "/api/v1/export/capnp", in_stream)
        capnp_data = collect_stream(out_capnp)
        @test capnp_data[1]["format"] == "capnp"
    end

    # 5. Schema Exports: OpenAPI & GraphQL SDL
    @testset "OpenAPI & GraphQL Schema Generation" begin
        t_taxon = TypeDescriptor("Taxon", [
            FieldDescriptor("id", PrimitiveType("String")),
            FieldDescriptor("name", PrimitiveType("String")),
            FieldDescriptor("rank", PrimitiveType("String"))
        ])
        
        m_list = MethodDescriptor("listTaxa", "Empty", "Taxon", streaming=ServerStreaming, route_path="/api/v1/taxa", http_method="GET")
        m_get = MethodDescriptor("getTaxon", "String", "Taxon", streaming=Unary, route_path="/api/v1/taxa/{id}", http_method="GET")
        
        svc_desc = ServiceDescriptor("RelationshipExplorerAPI", "1.0.0", [t_taxon], [m_list, m_get])
        
        # OpenAPI 3.1 JSON
        openapi_json = emit_openapi_json(svc_desc)
        @test occursin("openapi", openapi_json)
        @test occursin("3.1.0", openapi_json)
        @test occursin("/api/v1/taxa", openapi_json)
        
        # GraphQL SDL
        graphql_sdl = emit_graphql_sdl(svc_desc)
        @test occursin("type Taxon", graphql_sdl)
        @test occursin("type Query", graphql_sdl)
        @test occursin("listTaxa", graphql_sdl)
    end
end
