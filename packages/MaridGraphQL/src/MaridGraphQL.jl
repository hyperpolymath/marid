# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridGraphQL

GraphQL SDL schema generator and runtime introspection engine for Marid.
"""
module MaridGraphQL

using MaridIR

export emit_graphql_sdl, execute_graphql_query

"""
    emit_graphql_sdl(svc::ServiceDescriptor) -> String

Emits canonical GraphQL SDL schema from a service descriptor.
"""
function _type_name(ref::TypeRef)::String
    if ref isa PrimitiveType
        ref.name == "String" && return "String"
        ref.name in ["Int32", "Int64"] && return "Int"
        ref.name in ["Float32", "Float64"] && return "Float"
        ref.name == "Bool" && return "Boolean"
        ref.name == "ID" && return "ID"
        return "String"
    elseif ref isa ObjectType
        return ref.name
    elseif ref isa ListType
        return "[" * _type_name(ref.element_type) * "]"
    elseif ref isa OptionalType
        return _type_name(ref.inner_type)
    else
        return "String"
    end
end

function emit_graphql_sdl(svc::ServiceDescriptor)::String
    lines = String[]
    
    # Object Types
    for t in svc.types
        push!(lines, "type $(t.name) {")
        for f in t.fields
            tname = _type_name(f.type_ref)
            bang = f.nullable ? "" : "!"
            push!(lines, "  $(f.name): $tname$bang")
        end
        push!(lines, "}\n")
    end
    
    # Query Type
    queries = filter(m -> uppercase(m.http_method) == "GET", svc.methods)
    if !isempty(queries)
        push!(lines, "type Query {")
        for q in queries
            push!(lines, "  $(q.name)(input: $(q.input_type)): $(q.output_type)")
        end
        push!(lines, "}\n")
    end
    
    # Mutation Type
    mutations = filter(m -> uppercase(m.http_method) != "GET", svc.methods)
    if !isempty(mutations)
        push!(lines, "type Mutation {")
        for m in mutations
            push!(lines, "  $(m.name)(input: $(m.input_type)): $(m.output_type)")
        end
        push!(lines, "}\n")
    end
    
    return join(lines, "\n")
end

"""
    execute_graphql_query(query_str::String, svc::ServiceDescriptor) -> Dict{String, Any}

Handles basic introspection queries.
"""
function execute_graphql_query(query_str::String, svc::ServiceDescriptor)::Dict{String, Any}
    if occursin("__schema", query_str)
        return Dict{String, Any}(
            "data" => Dict{String, Any}(
                "__schema" => Dict{String, Any}(
                    "types" => [t.name for t in svc.types],
                    "queryType" => Dict("name" => "Query")
                )
            )
        )
    end
    return Dict{String, Any}("data" => Dict{String, Any}())
end

end # module MaridGraphQL
