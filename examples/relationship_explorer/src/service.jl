# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    TaxonService: Single source of business logic for Relationship Explorer.
"""

mutable struct TaxonService
    storage::StorageEngine
    id_counter::Int
end

TaxonService(storage::StorageEngine = InMemoryEngine()) = TaxonService(storage, 0)

function create_taxon!(svc::TaxonService, name::String, rank::String, characters::Vector{Int})::Taxon
    svc.id_counter += 1
    id = "taxon_$(svc.id_counter)"
    data = Dict{String, Any}(
        "id" => id,
        "name" => name,
        "rank" => rank,
        "characters" => characters
    )
    put_entity!(svc.storage, "taxa", id, data)
    return Taxon(id, name, rank, characters)
end

function get_taxon(svc::TaxonService, id::String)::Union{Nothing, Taxon}
    rec = get_entity(svc.storage, "taxa", id)
    rec === nothing && return nothing
    return Taxon(rec["id"], rec["name"], rec["rank"], rec["characters"])
end

function list_taxa(svc::TaxonService)::Vector{Taxon}
    recs = query_entities(svc.storage, "taxa")
    return [Taxon(r["id"], r["name"], r["rank"], r["characters"]) for r in recs]
end

function create_relationship!(svc::TaxonService, from_id::String, to_id::String, rel_type::String, weight::Float64=1.0)::Relationship
    svc.id_counter += 1
    id = "rel_$(svc.id_counter)"
    data = Dict{String, Any}(
        "id" => id,
        "from_id" => from_id,
        "to_id" => to_id,
        "rel_type" => rel_type,
        "weight" => weight,
        "_from" => "taxa/$from_id",
        "_to" => "taxa/$to_id"
    )
    put_entity!(svc.storage, "relationships", id, data)
    return Relationship(id, from_id, to_id, rel_type, weight)
end

function get_neighborhood(svc::TaxonService, center_id::String, depth::Int=1)::Neighborhood
    center = get_taxon(svc, center_id)
    center === nothing && throw(NotFoundError("Taxon", center_id))
    
    visited_nodes = Dict{String, Taxon}(center_id => center)
    collected_edges = Dict{String, Relationship}()
    
    current_layer = [center_id]
    for d in 1:depth
        next_layer = String[]
        all_edges = query_entities(svc.storage, "relationships")
        for e in all_edges
            rel = Relationship(e["id"], e["from_id"], e["to_id"], e["rel_type"], Float64(e["weight"]))
            if rel.from_id in current_layer || rel.to_id in current_layer
                collected_edges[rel.id] = rel
                other_id = rel.from_id in current_layer ? rel.to_id : rel.from_id
                if !haskey(visited_nodes, other_id)
                    t = get_taxon(svc, other_id)
                    if t !== nothing
                        visited_nodes[other_id] = t
                        push!(next_layer, other_id)
                    end
                end
            end
        end
        current_layer = next_layer
        isempty(current_layer) && break
    end
    
    return Neighborhood(
        center_id,
        depth,
        collect(values(visited_nodes)),
        collect(values(collected_edges))
    )
end

function execute_analysis(svc::TaxonService, taxon_ids::Vector{String}; on_progress::Function = (p) -> nothing)::AnalysisResult
    taxa = Taxon[]
    for id in taxon_ids
        t = get_taxon(svc, id)
        if t !== nothing
            push!(taxa, t)
        end
    end
    return run_cladistics_analysis(taxa, on_progress=on_progress)
end
