# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridIR.Proto

Protobuf syntax 3 schema generator emitting `.proto` definitions from `ServiceDescriptor`.
"""

export emit_proto

function _proto_type(ref::TypeRef)::String
    if ref isa PrimitiveType
        ref.name == "Int32" && return "int32"
        ref.name == "Int64" && return "int64"
        ref.name == "UInt32" && return "uint32"
        ref.name == "UInt64" && return "uint64"
        ref.name == "Float32" && return "float"
        ref.name == "Float64" && return "double"
        ref.name == "String" && return "string"
        ref.name == "Bool" && return "bool"
        ref.name == "Bytes" && return "bytes"
        ref.name == "Void" && return "google.protobuf.Empty"
        return "string"
    elseif ref isa ObjectType
        return ref.name
    elseif ref isa ListType
        return "repeated " * _proto_type(ref.element_type)
    elseif ref isa OptionalType
        return "optional " * _proto_type(ref.inner_type)
    elseif ref isa MapType
        return "map<" * _proto_type(ref.key_type) * ", " * _proto_type(ref.value_type) * ">"
    else
        return "string"
    end
end

function _snake_case(s::String)::String
    s = replace(s, r"([a-z0-9])([A-Z])" => s"\1_\2")
    return lowercase(replace(s, r"[^a-zA-Z0-9_]" => "_"))
end

"""
    emit_proto(svc::ServiceDescriptor) -> String

Emits canonical Protocol Buffers (proto3) schema text from a ServiceDescriptor.
"""
function emit_proto(svc::ServiceDescriptor)::String
    lines = String[]
    push!(lines, "// Protocol Buffers v3 Schema for $(svc.name) (v$(svc.version))")
    push!(lines, "// Emitted automatically by MaridIR")
    push!(lines, "syntax = \"proto3\";\n")
    
    pkg_name = _snake_case(svc.name)
    push!(lines, "package $pkg_name;\n")
    
    # Check if google.protobuf.Empty is needed
    needs_empty = any(m -> m.input_type == "Void" || m.output_type == "Void", svc.methods)
    if needs_empty
        push!(lines, "import \"google/protobuf/empty.proto\";\n")
    end
    
    # Emit Message Types
    for t in svc.types
        if !isempty(t.description)
            push!(lines, "/**")
            push!(lines, " * $(t.description)")
            push!(lines, " */")
        end
        push!(lines, "message $(t.name) {")
        for (idx, f) in enumerate(t.fields)
            ptype = _proto_type(f.type_ref)
            prefix = ""
            if f.nullable && !(f.type_ref isa ListType) && !(f.type_ref isa OptionalType)
                prefix = "optional "
            end
            push!(lines, "  $prefix$ptype $(f.name) = $idx;")
        end
        push!(lines, "}\n")
    end
    
    # Emit Service Definition
    if !isempty(svc.methods)
        if !isempty(svc.description)
            push!(lines, "/**")
            push!(lines, " * $(svc.description)")
            push!(lines, " */")
        end
        push!(lines, "service $(svc.name) {")
        for m in svc.methods
            in_stream = (m.streaming == ClientStreaming || m.streaming == BidirectionalStreaming) ? "stream " : ""
            out_stream = (m.streaming == ServerStreaming || m.streaming == BidirectionalStreaming) ? "stream " : ""
            in_t = m.input_type == "Void" ? "google.protobuf.Empty" : m.input_type
            out_t = m.output_type == "Void" ? "google.protobuf.Empty" : m.output_type
            push!(lines, "  rpc $(m.name) ($in_stream$in_t) returns ($out_stream$out_t);")
        end
        push!(lines, "}")
    end
    
    return join(lines, "\n")
end
