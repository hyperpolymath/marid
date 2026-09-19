# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridIR

Canonical Intermediate Representation (IR) for the Marid framework.
Pure data definitions for services, methods, types, and streaming semantics.
Zero dependencies.
"""
module MaridIR

export FieldDescriptor, TypeDescriptor, MethodDescriptor, ServiceDescriptor,
       StreamingMode, Unary, ServerStreaming, ClientStreaming, BidirectionalStreaming,
       validate_service

@enum StreamingMode begin
    Unary
    ServerStreaming
    ClientStreaming
    BidirectionalStreaming
end

struct FieldDescriptor
    name::String
    type_name::String
    nullable::Bool
    description::String
end

FieldDescriptor(name::String, type_name::String; nullable::Bool=false, description::String="") =
    FieldDescriptor(name, type_name, nullable, description)

struct TypeDescriptor
    name::String
    fields::Vector{FieldDescriptor}
    description::String
end

TypeDescriptor(name::String, fields::Vector{FieldDescriptor}; description::String="") =
    TypeDescriptor(name, fields, description)

struct MethodDescriptor
    name::String
    input_type::String
    output_type::String
    streaming::StreamingMode
    route_path::String
    http_method::String
    description::String
end

MethodDescriptor(name::String, input_type::String, output_type::String;
                 streaming::StreamingMode=Unary, route_path::String="", http_method::String="POST", description::String="") =
    MethodDescriptor(name, input_type, output_type, streaming, route_path, http_method, description)

struct ServiceDescriptor
    name::String
    version::String
    types::Vector{TypeDescriptor}
    methods::Vector{MethodDescriptor}
    description::String
end

ServiceDescriptor(name::String, version::String, types::Vector{TypeDescriptor}, methods::Vector{MethodDescriptor}; description::String="") =
    ServiceDescriptor(name, version, types, methods, description)

"""
    validate_service(svc::ServiceDescriptor) -> Bool

Validates that all method input and output types are registered in the service types
or correspond to primitive types, and checks for duplicate names.
"""
function validate_service(svc::ServiceDescriptor)::Bool
    # Check duplicate types
    type_names = Set{String}()
    for t in svc.types
        t.name in type_names && error("Duplicate type name: $(t.name)")
        push!(type_names, t.name)
    end
    
    # Primitive types
    primitives = Set{String}(["String", "Int32", "Int64", "UInt32", "UInt64", "Float32", "Float64", "Bool", "Bytes", "Void"])
    all_known = union(type_names, primitives)
    
    # Check method signatures
    method_names = Set{String}()
    for m in svc.methods
        m.name in method_names && error("Duplicate method name: $(m.name)")
        push!(method_names, m.name)
        
        !(m.input_type in all_known) && error("Unknown input type $(m.input_type) in method $(m.name)")
        !(m.output_type in all_known) && error("Unknown output type $(m.output_type) in method $(m.name)")
    end
    
    return true
end

end # module MaridIR
