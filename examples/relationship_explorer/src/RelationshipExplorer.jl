# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    RelationshipExplorer

Reference application for Marid framework.
Demonstrates multi-protocol service exposure, ArangoDB backing,
neighborhood graph exploration, and streaming cladistics analysis.
"""
module RelationshipExplorer

using Dates
using UUIDs
using MaridCore
using MaridIR
using MaridStorage
using ArangoDB
using MaridGraphQL
using MaridOpenAPI
using MaridTransport

include("domain.jl")
include("analysis.jl")
include("service.jl")
include("server.jl")

export Taxon, Relationship, Neighborhood, AnalysisProgress, AnalysisResult,
       TaxonService, create_taxon!, get_taxon, list_taxa, create_relationship!,
       get_neighborhood, execute_analysis, build_app, service_descriptor

end # module RelationshipExplorer
