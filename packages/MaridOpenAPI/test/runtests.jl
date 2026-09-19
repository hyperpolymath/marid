# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridIR
using MaridOpenAPI

@testset "MaridOpenAPI Tests" begin
    m = MethodDescriptor("getTaxon", "String", "Taxon", route_path="/taxon/:id", http_method="GET", description="Retrieve taxon")
    svc = ServiceDescriptor("TaxonomyService", "1.0.0", TypeDescriptor[], [m])
    
    spec = emit_openapi_json(svc)
    
    @test occursin("\"openapi\": \"3.1.0\"", spec)
    @test occursin("\"title\": \"TaxonomyService\"", spec)
    @test occursin("\"/taxon/:id\"", spec)
    @test occursin("\"operationId\": \"getTaxon\"", spec)
end
