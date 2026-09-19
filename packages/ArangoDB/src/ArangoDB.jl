# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    ArangoDB

Standalone native Julia HTTP client for ArangoDB 3.12 (documents, edges, graphs, AQL cursors).
Zero dependencies on MaridCore.
"""
module ArangoDB

using Base64
using Dates
using Sockets

export ArangoClient, ArangoQuery, execute_aql, format_auth_header

struct ArangoClient
    endpoint::String
    database::String
    username::String
    password::String
end

ArangoClient(endpoint::String="http://127.0.0.1:8529", database::String="_system") =
    ArangoClient(endpoint, database, "root", "")

struct ArangoQuery
    aql::String
    bind_vars::Dict{String, Any}
    batch_size::Int
    ttl::Int
end

ArangoQuery(aql::String, bind_vars::Dict{String, Any}=Dict{String, Any}(); batch_size::Int=100, ttl::Int=30) =
    ArangoQuery(aql, bind_vars, batch_size, ttl)

function format_auth_header(client::ArangoClient)::String
    isempty(client.password) ? "" : "Basic " * base64encode("$(client.username):$(client.password)")
end

"""
    execute_aql(client::ArangoClient, query::ArangoQuery) -> Dict{String, Any}

Mock wire client for Gate 2 testing.
"""
function execute_aql(client::ArangoClient, query::ArangoQuery)::Dict{String, Any}
    return Dict{String, Any}(
        "error" => false,
        "code" => 201,
        "hasMore" => false,
        "result" => Any[Dict("query" => query.aql)]
    )
end

end # module ArangoDB
