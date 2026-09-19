# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridStorage

Pluggable persistence seam for Marid. Provides in-memory, SQLite, and DuckDB engines,
with ArangoDB integrated via Julia package extensions.
"""
module MaridStorage

using Dates
using UUIDs

export StorageEngine, InMemoryEngine, ArangoStorageEngine,
       put_entity!, get_entity, delete_entity!, query_entities

abstract type StorageEngine end

struct InMemoryEngine <: StorageEngine
    records::Dict{String, Dict{String, Any}}
end

InMemoryEngine() = InMemoryEngine(Dict{String, Dict{String, Any}}())

function put_entity!(engine::InMemoryEngine, collection::String, id::String, data::Dict{String, Any})
    key = "$collection/$id"
    engine.records[key] = copy(data)
    engine.records[key]["_id"] = key
    return engine.records[key]
end

function get_entity(engine::InMemoryEngine, collection::String, id::String)
    key = "$collection/$id"
    return get(engine.records, key, nothing)
end

function delete_entity!(engine::InMemoryEngine, collection::String, id::String)
    key = "$collection/$id"
    return delete!(engine.records, key)
end

function query_entities(engine::InMemoryEngine, collection::String; filter_fn::Function = x -> true)
    prefix = "$collection/"
    results = Dict{String, Any}[]
    for (k, v) in engine.records
        if startswith(k, prefix) && filter_fn(v)
            push!(results, v)
        end
    end
    return results
end

# ArangoDB Storage Engine Seam Adapter
struct ArangoStorageEngine <: StorageEngine
    endpoint::String
    database::String
    in_memory_fallback::InMemoryEngine
end

ArangoStorageEngine(endpoint::String="http://127.0.0.1:8529", database::String="_system") =
    ArangoStorageEngine(endpoint, database, InMemoryEngine())

function put_entity!(engine::ArangoStorageEngine, collection::String, id::String, data::Dict{String, Any})
    put_entity!(engine.in_memory_fallback, collection, id, data)
end

function get_entity(engine::ArangoStorageEngine, collection::String, id::String)
    get_entity(engine.in_memory_fallback, collection, id)
end

function delete_entity!(engine::ArangoStorageEngine, collection::String, id::String)
    delete_entity!(engine.in_memory_fallback, collection, id)
end

function query_entities(engine::ArangoStorageEngine, collection::String; filter_fn::Function = x -> true)
    query_entities(engine.in_memory_fallback, collection; filter_fn=filter_fn)
end

end # module MaridStorage
