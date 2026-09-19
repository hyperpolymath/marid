# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    Cladistic analysis engine for the Relationship Explorer reference application.
    Computes character-state distance matrices, minimal parsimony step scores,
    and streams incremental progress updates.
"""

function compute_hamming_distance(c1::Vector{Int}, c2::Vector{Int})::Float64
    len = min(length(c1), length(c2))
    len == 0 && return 0.0
    diffs = 0
    for i in 1:len
        if c1[i] != c2[i]
            diffs += 1
        end
    end
    return Float64(diffs) / Float64(len)
end

function run_cladistics_analysis(taxa::Vector{Taxon}; on_progress::Function = (p) -> nothing)::AnalysisResult
    n = length(taxa)
    n == 0 && return AnalysisResult("();", 0.0, String[], zeros(0, 0))
    
    # Stage 1: Distance matrix computation
    on_progress(AnalysisProgress(1, 4, "Computing pairwise character distances", 0.0))
    dist_mat = zeros(Float64, n, n)
    for i in 1:n
        for j in 1:n
            if i != j
                dist_mat[i, j] = compute_hamming_distance(taxa[i].characters, taxa[j].characters)
            end
        end
    end
    
    # Stage 2: Parsimony score calculation
    on_progress(AnalysisProgress(2, 4, "Calculating character transition costs", 0.25))
    total_parsimony = 0.0
    for col in 1:maximum(t -> length(t.characters), taxa; init=0)
        states = Set{Int}()
        for t in taxa
            if col <= length(t.characters)
                push!(states, t.characters[col])
            end
        end
        total_parsimony += max(0, length(states) - 1)
    end
    
    # Stage 3: Hierarchical tree construction
    on_progress(AnalysisProgress(3, 4, "Reconstructing phylogenetic topology", 0.75))
    # Simple Newick synthesis for reference demonstration
    taxa_names = [t.name for t in taxa]
    newick = "(" * join(taxa_names, ",") * ");"
    
    # Stage 4: Finalization
    on_progress(AnalysisProgress(4, 4, "Complete", total_parsimony))
    
    return AnalysisResult(newick, total_parsimony, taxa_names, dist_mat)
end
