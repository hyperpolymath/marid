# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridIR

@testset "MaridIR Tests" begin
    # 1. Type construction
    field1 = FieldDescriptor("id", "String", nullable=false, description="Primary ID")
    field2 = FieldDescriptor("score", "Float64", nullable=true, description="Confidence score")
    taxon_type = TypeDescriptor("Taxon", [field1, field2], description="Taxon entity")
    
    @test taxon_type.name == "Taxon"
    @test length(taxon_type.fields) == 2
    
    # 2. Method construction
    m1 = MethodDescriptor("getTaxon", "String", "Taxon", streaming=Unary, route_path="/taxon/:id", http_method="GET")
    @test m1.streaming == Unary
    @test m1.http_method == "GET"
    
    # 3. Service validation - Success
    svc = ServiceDescriptor("TaxonomyService", "1.0.0", [taxon_type], [m1])
    @test validate_service(svc) == true
    
    # 4. Service validation - Unknown type failure
    bad_method = MethodDescriptor("badMethod", "UnregisteredType", "Taxon")
    bad_svc = ServiceDescriptor("BadService", "1.0.0", [taxon_type], [bad_method])
    @test_throws ErrorException validate_service(bad_svc)
end
