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
    # 5. Protobuf v3 Schema Generator
    @testset "Protobuf Schema Emission" begin
        t_taxon = TypeDescriptor("Taxon", [
            FieldDescriptor("id", PrimitiveType("String")),
            FieldDescriptor("name", PrimitiveType("String")),
            FieldDescriptor("characters", ListType(PrimitiveType("Int32"))),
            FieldDescriptor("notes", PrimitiveType("String"), nullable=true)
        ])
        
        m_get = MethodDescriptor("GetTaxon", "TaxonQuery", "Taxon", streaming=Unary)
        m_stream = MethodDescriptor("StreamTaxa", "TaxonQuery", "Taxon", streaming=ServerStreaming)
        m_chat = MethodDescriptor("Chat", "TaxonMessage", "TaxonMessage", streaming=BidirectionalStreaming)
        
        svc = ServiceDescriptor("TaxonomyService", "1.0.0", [t_taxon], [m_get, m_stream, m_chat])
        proto_txt = emit_proto(svc)
        
        @test occursin("syntax = \"proto3\";", proto_txt)
        @test occursin("package taxonomy_service;", proto_txt)
        @test occursin("message Taxon {", proto_txt)
        @test occursin("string id = 1;", proto_txt)
        @test occursin("repeated int32 characters = 3;", proto_txt)
        @test occursin("optional string notes = 4;", proto_txt)
        @test occursin("service TaxonomyService {", proto_txt)
        @test occursin("rpc GetTaxon (TaxonQuery) returns (Taxon);", proto_txt)
        @test occursin("rpc StreamTaxa (TaxonQuery) returns (stream Taxon);", proto_txt)
        @test occursin("rpc Chat (stream TaxonMessage) returns (stream TaxonMessage);", proto_txt)
    end

    # 6. http-capability-gateway Verb Governance Spec (DSL v1) Generator
    @testset "Capability Spec Emission" begin
        # Test standard route emission with :param and annotations
        cap_ann = Annotation("capability", "taxa:read")
        exp_ann = Annotation("exposure", "authenticated")
        m_get = MethodDescriptor("getTaxon", "String", "TaxonNode", streaming=Unary,
                                 route_path="/api/v1/taxa/:id", http_method="GET",
                                 description="Fetch taxon by ID", annotations=[cap_ann, exp_ann])
        m_del = MethodDescriptor("deleteTaxon", "String", "Void", streaming=Unary,
                                 route_path="/api/v1/taxa/:id", http_method="DELETE",
                                 description="Delete taxon by ID", annotations=[Annotation("capability", "taxa:delete")])
        m_create = MethodDescriptor("createTaxon", "TaxonNode", "TaxonNode", streaming=Unary,
                                    route_path="/api/v1/taxa", http_method="POST",
                                    description="Create new taxon")
        m_patch = MethodDescriptor("patchTaxon", "TaxonNode", "TaxonNode", streaming=Unary,
                                   route_path="/api/v1/taxa/{id}", http_method="PATCH",
                                   description="Patch taxon")

        svc_cap = ServiceDescriptor("TaxonomyService", "1.0.0", [taxon_type], [m_get, m_del, m_create, m_patch])
        spec_yaml = emit_capability_spec(svc_cap)

        # Basic DSL v1 header and structure
        @test occursin("dsl_version: \"1\"", spec_yaml)
        @test occursin("governance:", spec_yaml)
        @test occursin("global_verbs:", spec_yaml)
        @test occursin("- GET", spec_yaml)
        @test occursin("- POST", spec_yaml)

        # Route regex normalization (:id -> [^/]+)
        @test occursin("path: \"^/api/v1/taxa/[^/]+\$\"", spec_yaml)
        # Multiple verbs grouped on same path
        @test occursin("- GET", spec_yaml)
        @test occursin("- DELETE", spec_yaml)
        # Capability label from annotation
        @test occursin("capability: \"taxa:read, taxa:delete, TaxonomyService.patchTaxon\"", spec_yaml)
        @test occursin("exposure: authenticated", spec_yaml)

        # Route normalization ({id} -> [^/]+)
        @test occursin("- PATCH", spec_yaml)

        # POST route without param
        @test occursin("path: \"^/api/v1/taxa\$\"", spec_yaml)

        # Stealth configuration
        @test occursin("stealth:", spec_yaml)
        @test occursin("enabled: true", spec_yaml)
        @test occursin("status_code: 404", spec_yaml)

        # Custom options test
        custom_spec = emit_capability_spec(svc_cap; global_verbs=["GET"], stealth_enabled=false, stealth_status=403)
        @test occursin("- GET", custom_spec)
        @test !occursin("- POST\n\n  routes:", custom_spec)
        @test occursin("enabled: false", custom_spec)
        @test occursin("status_code: 403", custom_spec)

        # Invalid arguments rejection
        @test_throws ErrorException emit_capability_spec(svc_cap; global_verbs=["INVALID_VERB"])
        @test_throws ErrorException emit_capability_spec(svc_cap; stealth_status=99)
        @test_throws ErrorException emit_capability_spec(svc_cap; stealth_status=600)
    end
end
