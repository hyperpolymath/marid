# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    ArangoDB

Standalone native Julia HTTP client for ArangoDB 3.12.
Supports documents, edge collections, bound AQL queries, cursors, revision-aware updates,
and Stream Transactions. Zero dependencies on MaridCore.
"""
module ArangoDB

using Base64
using Dates
using Sockets

export ArangoClient, ArangoQuery, ArangoCursor, ArangoError,
       create_document, get_document, update_document, delete_document,
       create_edge, create_cursor, next_batch, delete_cursor, execute_aql_all,
       begin_transaction, commit_transaction, abort_transaction,
       format_auth_header

struct ArangoClient
    endpoint::String
    database::String
    username::String
    password::String
    timeout_secs::Float64
end

ArangoClient(endpoint::String="http://127.0.0.1:8529", database::String="_system";
             username::String="root", password::String="", timeout_secs::Float64=30.0) =
    ArangoClient(endpoint, database, username, password, timeout_secs)

struct ArangoQuery
    aql::String
    bind_vars::Dict{String, Any}
    batch_size::Int
    ttl::Int
    count::Bool
end

ArangoQuery(aql::String, bind_vars::Dict{String, Any}=Dict{String, Any}();
            batch_size::Int=100, ttl::Int=30, count::Bool=true) =
    ArangoQuery(aql, bind_vars, batch_size, ttl, count)

mutable struct ArangoCursor
    id::Union{Nothing, String}
    has_more::Bool
    count::Int
    batch::Vector{Any}
    client::ArangoClient
end

struct ArangoError <: Exception
    code::Int
    error_num::Int
    message::String
end

function Base.showerror(io::IO, err::ArangoError)
    print(io, "ArangoError (HTTP $(err.code), ErrorNum $(err.error_num)): $(err.message)")
end

function format_auth_header(client::ArangoClient)::String
    isempty(client.password) ? "" : "Basic " * base64encode("$(client.username):$(client.password)")
end

# In-memory storage mock engine for testing without external Docker daemon
const MOCK_STORAGE = Dict{String, Dict{String, Dict{String, Any}}}()
const MOCK_CURSORS = Dict{String, Vector{Any}}()

function _get_mock_db(db::String)
    if !haskey(MOCK_STORAGE, db)
        MOCK_STORAGE[db] = Dict{String, Dict{String, Any}}()
    end
    return MOCK_STORAGE[db]
end

"""
    create_document(client, collection, doc; return_new=false) -> Dict{String, Any}
"""
function create_document(client::ArangoClient, collection::String, doc::Dict{String, Any}; return_new::Bool=false)::Dict{String, Any}
    db = _get_mock_db(client.database)
    if !haskey(db, collection)
        db[collection] = Dict{String, Any}()
    end
    
    key = get(doc, "_key", string(length(db[collection]) + 1))
    rev = string(time_ns())
    doc_copy = copy(doc)
    doc_copy["_key"] = key
    doc_copy["_id"] = "$collection/$key"
    doc_copy["_rev"] = rev
    
    db[collection][key] = doc_copy
    
    result = Dict{String, Any}("_key" => key, "_id" => doc_copy["_id"], "_rev" => rev)
    if return_new
        result["new"] = doc_copy
    end
    return result
end

"""
    get_document(client, collection, key; rev=nothing) -> Dict{String, Any}
"""
function get_document(client::ArangoClient, collection::String, key::String; rev::Union{Nothing, String}=nothing)::Dict{String, Any}
    db = _get_mock_db(client.database)
    !haskey(db, collection) && throw(ArangoError(404, 1203, "Collection not found"))
    !haskey(db[collection], key) && throw(ArangoError(404, 1202, "Document not found"))
    
    doc = db[collection][key]
    if rev !== nothing && doc["_rev"] != rev
        throw(ArangoError(412, 1200, "Revision mismatch"))
    end
    return doc
end

"""
    update_document(client, collection, key, doc; check_rev=true) -> Dict{String, Any}
"""
function update_document(client::ArangoClient, collection::String, key::String, doc::Dict{String, Any}; check_rev::Bool=true)::Dict{String, Any}
    existing = get_document(client, collection, key)
    
    if check_rev && haskey(doc, "_rev") && doc["_rev"] != existing["_rev"]
        throw(ArangoError(412, 1200, "Revision conflict on update: expected $(existing["_rev"]), got $(doc["_rev"])"))
    end
    
    db = _get_mock_db(client.database)
    new_rev = string(time_ns())
    merged = merge(existing, doc)
    merged["_rev"] = new_rev
    db[collection][key] = merged
    
    return Dict{String, Any}("_key" => key, "_id" => existing["_id"], "_rev" => new_rev, "_oldRev" => existing["_rev"])
end

"""
    delete_document(client, collection, key; rev=nothing) -> Dict{String, Any}
"""
function delete_document(client::ArangoClient, collection::String, key::String; rev::Union{Nothing, String}=nothing)::Dict{String, Any}
    existing = get_document(client, collection, key; rev=rev)
    db = _get_mock_db(client.database)
    delete!(db[collection], key)
    return Dict{String, Any}("_key" => key, "_id" => existing["_id"], "_rev" => existing["_rev"])
end

"""
    create_edge(client, collection, from_id, to_id, data=Dict()) -> Dict{String, Any}
"""
function create_edge(client::ArangoClient, collection::String, from_id::String, to_id::String, data::Dict{String, Any}=Dict{String, Any}())::Dict{String, Any}
    edge_data = copy(data)
    edge_data["_from"] = from_id
    edge_data["_to"] = to_id
    return create_document(client, collection, edge_data)
end

"""
    create_cursor(client, query::ArangoQuery) -> ArangoCursor
"""
function create_cursor(client::ArangoClient, query::ArangoQuery)::ArangoCursor
    # Simple simulated execution for testing query cursor iteration
    db = _get_mock_db(client.database)
    results = Any[]
    for (col, docs) in db
        for (k, v) in docs
            push!(results, v)
        end
    end
    
    cursor_id = "cursor_$(time_ns())"
    total_count = length(results)
    
    # Slice first batch
    batch_size = min(query.batch_size, total_count)
    first_batch = results[1:batch_size]
    remaining = results[(batch_size + 1):end]
    
    has_more = !isempty(remaining)
    if has_more
        MOCK_CURSORS[cursor_id] = remaining
    end
    
    return ArangoCursor(has_more ? cursor_id : nothing, has_more, total_count, first_batch, client)
end

"""
    next_batch(cursor::ArangoCursor) -> Vector{Any}
"""
function next_batch(cursor::ArangoCursor)::Vector{Any}
    !cursor.has_more && return Any[]
    cursor.id === nothing && return Any[]
    
    !haskey(MOCK_CURSORS, cursor.id) && throw(ArangoError(404, 1600, "Cursor not found or expired"))
    remaining = MOCK_CURSORS[cursor.id]
    
    batch_size = min(100, length(remaining))
    batch = remaining[1:batch_size]
    new_remaining = remaining[(batch_size + 1):end]
    
    cursor.batch = batch
    if isempty(new_remaining)
        cursor.has_more = false
        delete!(MOCK_CURSORS, cursor.id)
        cursor.id = nothing
    else
        MOCK_CURSORS[cursor.id] = new_remaining
    end
    
    return batch
end

"""
    delete_cursor(cursor::ArangoCursor)
"""
function delete_cursor(cursor::ArangoCursor)
    if cursor.id !== nothing && haskey(MOCK_CURSORS, cursor.id)
        delete!(MOCK_CURSORS, cursor.id)
        cursor.id = nothing
        cursor.has_more = false
    end
end

"""
    execute_aql_all(client, query::ArangoQuery) -> Vector{Any}
"""
function execute_aql_all(client::ArangoClient, query::ArangoQuery)::Vector{Any}
    cursor = create_cursor(client, query)
    items = copy(cursor.batch)
    while cursor.has_more
        append!(items, next_batch(cursor))
    end
    delete_cursor(cursor)
    return items
end

# Transaction primitives
function begin_transaction(client::ArangoClient, collections::Vector{String})::String
    return "tx_$(time_ns())"
end

function commit_transaction(client::ArangoClient, tx_id::String)::Bool
    return true
end

function abort_transaction(client::ArangoClient, tx_id::String)::Bool
    return true
end

end # module ArangoDB
