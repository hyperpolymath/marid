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

export StorageEngine, InMemoryEngine, put_entity!, get_entity, delete_entity!

abstract type StorageEngine end

struct InMemoryEngine <: StorageEngine
    records::Dict{String, Dict{String, Any}}
end

InMemoryEngine() = InMemoryEngine(Dict{String, Dict{String, Any}}())

function put_entity!(engine::InMemoryEngine, collection::String, id::String, data::Dict{String, Any})
    key = "$collection/$id"
    engine.records[key] = data
    return data
end

function get_entity(engine::InMemoryEngine, collection::String, id::String)
    key = "$collection/$id"
    return get(engine.records, key, nothing)
end

function delete_entity!(engine::InMemoryEngine, collection::String, id::String)
    key = "$collection/$id"
    return delete!(engine.records, key)
end

end # module MaridStorage
