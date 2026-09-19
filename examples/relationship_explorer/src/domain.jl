# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    Domain entities for the Relationship Explorer reference application.
"""

struct Taxon
    id::String
    name::String
    rank::String
    characters::Vector{Int}
end

struct Relationship
    id::String
    from_id::String
    to_id::String
    rel_type::String
    weight::Float64
end

struct Neighborhood
    center_id::String
    depth::Int
    nodes::Vector{Taxon}
    edges::Vector{Relationship}
end

struct AnalysisProgress
    step::Int
    total_steps::Int
    stage::String
    current_score::Float64
end

struct AnalysisResult
    tree_newick::String
    parsimony_score::Float64
    taxa::Vector{String}
    distance_matrix::Matrix{Float64}
end
