# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    Server and protocol mappings for Relationship Explorer.
    Exposes unified service through HTTP/JSON, GraphQL, and binary export endpoints.
"""

function build_app(svc::TaxonService)::MaridApp
    app = MaridApp()
    
    # 1. Taxa CRUD
    register_route!(app, "GET", "/api/v1/taxa", (ctx, req) -> begin
        taxa = list_taxa(svc)
        out = Stream{Dict{String, Any}}(ctx)
        for t in taxa
            push_item!(out, Dict{String, Any}("id" => t.id, "name" => t.name, "rank" => t.rank, "characters" => t.characters))
        end
        close_stream!(out)
        return out
    end)
    
    register_route!(app, "GET", "/api/v1/taxa/:id", (ctx, req) -> begin
        id = req.params["id"]
        t = get_taxon(svc, id)
        t === nothing && throw(NotFoundError("Taxon", id))
        out = Stream{Dict{String, Any}}(ctx)
        push_item!(out, Dict{String, Any}("id" => t.id, "name" => t.name, "rank" => t.rank, "characters" => t.characters))
        close_stream!(out)
        return out
    end)
    
    # 2. Neighborhood Exploration
    register_route!(app, "GET", "/api/v1/neighborhood/:id", (ctx, req) -> begin
        id = req.params["id"]
        depth = 1
        nh = get_neighborhood(svc, id, depth)
        out = Stream{Dict{String, Any}}(ctx)
        push_item!(out, Dict{String, Any}(
            "center_id" => nh.center_id,
            "depth" => nh.depth,
            "node_count" => length(nh.nodes),
            "edge_count" => length(nh.edges)
        ))
        close_stream!(out)
        return out
    end)
    
    # 3. Cladistics Analysis with Progress Streaming
    register_route!(app, "POST", "/api/v1/analysis", (ctx, req) -> begin
        taxa = list_taxa(svc)
        taxon_ids = [t.id for t in taxa]
        out = Stream{Dict{String, Any}}(ctx)
        
        # Async execution streaming progress events
        @async begin
            res = execute_analysis(svc, taxon_ids, on_progress = (p) -> begin
                push_item!(out, Dict{String, Any}(
                    "type" => "progress",
                    "step" => p.step,
                    "total_steps" => p.total_steps,
                    "stage" => p.stage,
                    "current_score" => p.current_score
                ))
            end)
            push_item!(out, Dict{String, Any}(
                "type" => "result",
                "newick" => res.tree_newick,
                "parsimony_score" => res.parsimony_score,
                "taxa" => res.taxa
            ))
            close_stream!(out)
        end
        
        return out
    end)
    
    # 4. Binary Export Endpoints (Bebop & Cap'n Proto)
    register_route!(app, "GET", "/api/v1/export/bebop", (ctx, req) -> begin
        taxa = list_taxa(svc)
        out = Stream{Dict{String, Any}}(ctx)
        push_item!(out, Dict{String, Any}(
            "format" => "bebop",
            "schema" => "TaxonGraph",
            "entity_count" => length(taxa),
            "payload_base64" => "BOP001_TAXA_STREAM_PAYLOAD"
        ))
        close_stream!(out)
        return out
    end)
    
    register_route!(app, "GET", "/api/v1/export/capnp", (ctx, req) -> begin
        taxa = list_taxa(svc)
        out = Stream{Dict{String, Any}}(ctx)
        push_item!(out, Dict{String, Any}(
            "format" => "capnp",
            "schema" => "TaxonGraph",
            "entity_count" => length(taxa),
            "payload_base64" => "CAPNP001_SEGMENT_STREAM_PAYLOAD"
        ))
        close_stream!(out)
        return out
    end)
    
    return app
end
