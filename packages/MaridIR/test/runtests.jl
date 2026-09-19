# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridIR

@testset "MaridIR Golden Suite" begin
    # 1. Type and Field Descriptors
    f_id = FieldDescriptor("id", "String", nullable=false, description="Taxon ID")
    f_name = FieldDescriptor("name", "String", nullable=false, description="Scientific binomial")
    f_parent = FieldDescriptor("parent_id", "String", nullable=true, description="Parent clade ID")
    f_weight = FieldDescriptor("bootstrap_support", PrimitiveType("Float64"), nullable=true, description="Branch support")
    
    taxon_type = TypeDescriptor("TaxonNode", [f_id, f_name, f_parent, f_weight], description="Phylogenetic clade node")
    
    @test taxon_type.name == "TaxonNode"
    @test length(taxon_type.fields) == 4
    
    # 2. Methods with annotations
    auth_ann = Annotation("auth", "role:researcher")
    m_get = MethodDescriptor("getTaxon", "String", "TaxonNode", streaming=Unary, route_path="/api/v1/taxa/:id", http_method="GET",
                             description="Fetch taxon by ID", annotations=[auth_ann])
    
    m_stream = MethodDescriptor("streamClades", "String", "TaxonNode", streaming=ServerStreaming, route_path="/api/v1/taxa/stream", http_method="GET",
                                description="Stream clades")
                                
    # 3. Valid Service Definition
    svc = ServiceDescriptor("TaxonomyService", "1.0.0", [taxon_type], [m_get, m_stream], description="Phylogenetic taxonomy API")
    @test validate_service(svc) == true
    
    # 4. Golden dictionary representation
    d = to_dict(svc)
    @test d["name"] == "TaxonomyService"
    @test d["version"] == "1.0.0"
    @test length(d["types"]) == 1
    @test length(d["methods"]) == 2
    @test d["methods"][2]["streaming"] == "ServerStreaming"
    
    # 5. Validation Rejection - Route collision
    m_dup_route = MethodDescriptor("getTaxonAlt", "String", "TaxonNode", route_path="/api/v1/taxa/:id", http_method="GET")
    bad_svc_route = ServiceDescriptor("CollisionService", "1.0.0", [taxon_type], [m_get, m_dup_route])
    @test_throws ErrorException validate_service(bad_svc_route)
    
    # 6. Validation Rejection - Duplicate field in type
    f_dup = FieldDescriptor("id", "Int64")
    bad_type = TypeDescriptor("BadTaxon", [f_id, f_dup])
    bad_svc_field = ServiceDescriptor("BadFieldService", "1.0.0", [bad_type], MethodDescriptor[])
    @test_throws ErrorException validate_service(bad_svc_field)
    
    # 7. Validation Rejection - Empty service name
    empty_svc = ServiceDescriptor("", "1.0.0", TypeDescriptor[], MethodDescriptor[])
    @test_throws ErrorException validate_service(empty_svc)
end
