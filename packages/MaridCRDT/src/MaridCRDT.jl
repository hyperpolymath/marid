# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCRDT

Conflict-Free Replicated Data Types (CvRDTs) for Marid:
- G-Counter (Grow-Only Counter)
- PN-Counter (Positive-Negative Counter)
- LWW-Register (Last-Write-Wins Register with deterministic tie-breaker)
- OR-Set (Observed-Removed Set with add-wins semantics)
- PresenceMap (Distributed peer presence with heartbeat timestamps)
- Partition simulator for strong eventual consistency (SEC) verification.
"""
module MaridCRDT

using Dates
using UUIDs

export GCounter, inc!, value, merge_crdt,
       PNCounter, dec!,
       LWWRegister, set_value!,
       ORSet, add_element!, remove_element!, read_elements, has_element,
       PresenceMap, update_presence!, reap_stale_presence!, get_active_presence

# 1. G-Counter (Grow-Only Counter)
struct GCounter
    counts::Dict{String, Int}
end

GCounter() = GCounter(Dict{String, Int}())

function inc!(c::GCounter, node_id::String, delta::Int=1)::GCounter
    delta < 0 && error("GCounter increment delta must be non-negative")
    c.counts[node_id] = get(c.counts, node_id, 0) + delta
    return c
end

value(c::GCounter)::Int = sum(values(c.counts); init=0)

function merge_crdt(a::GCounter, b::GCounter)::GCounter
    merged = Dict{String, Int}()
    all_keys = union(keys(a.counts), keys(b.counts))
    for k in all_keys
        merged[k] = max(get(a.counts, k, 0), get(b.counts, k, 0))
    end
    return GCounter(merged)
end

# 2. PN-Counter (Positive-Negative Counter)
struct PNCounter
    pos::GCounter
    neg::GCounter
end

PNCounter() = PNCounter(GCounter(), GCounter())

function inc!(c::PNCounter, node_id::String, delta::Int=1)::PNCounter
    inc!(c.pos, node_id, delta)
    return c
end

function dec!(c::PNCounter, node_id::String, delta::Int=1)::PNCounter
    inc!(c.neg, node_id, delta)
    return c
end

value(c::PNCounter)::Int = value(c.pos) - value(c.neg)

function merge_crdt(a::PNCounter, b::PNCounter)::PNCounter
    return PNCounter(merge_crdt(a.pos, b.pos), merge_crdt(a.neg, b.neg))
end

# 3. LWW-Register (Last-Write-Wins Register)
struct LWWRegister{T}
    val::T
    timestamp::UInt64
    writer_id::String
end

LWWRegister(initial::T) where T = LWWRegister{T}(initial, 0, "")

function set_value!(reg::LWWRegister{T}, new_val::T, ts::Integer, writer::String)::LWWRegister{T} where T
    return LWWRegister{T}(new_val, UInt64(ts), writer)
end

value(reg::LWWRegister) = reg.val

function merge_crdt(a::LWWRegister{T}, b::LWWRegister{T})::LWWRegister{T} where T
    if a.timestamp > b.timestamp
        return a
    elseif b.timestamp > a.timestamp
        return b
    else
        # Deterministic tie-breaker on writer ID
        return a.writer_id >= b.writer_id ? a : b
    end
end

# 4. OR-Set (Observed-Remove Set with Add-Wins)
struct ORSet{T}
    adds::Dict{Tuple{T, String}, UInt64}
    rems::Dict{Tuple{T, String}, UInt64}
end

ORSet{T}() where T = ORSet{T}(Dict{Tuple{T, String}, UInt64}(), Dict{Tuple{T, String}, UInt64}())

function add_element!(s::ORSet{T}, elem::T, tag::String=string(uuid4()), ts::Integer=time_ns())::String where T
    s.adds[(elem, tag)] = UInt64(ts)
    return tag
end

function remove_element!(s::ORSet{T}, elem::T, ts::Integer=time_ns()) where T
    for ((e, tag), add_ts) in s.adds
        if e == elem
            s.rems[(e, tag)] = UInt64(ts)
        end
    end
    return s
end

function read_elements(s::ORSet{T})::Set{T} where T
    live = Set{T}()
    for ((elem, tag), add_ts) in s.adds
        rem_ts = get(s.rems, (elem, tag), UInt64(0))
        # Add-wins: if not removed or add timestamp strictly greater than remove
        if rem_ts == 0 || add_ts > rem_ts
            push!(live, elem)
        end
    end
    return live
end

function has_element(s::ORSet{T}, elem::T)::Bool where T
    return elem in read_elements(s)
end

function merge_crdt(a::ORSet{T}, b::ORSet{T})::ORSet{T} where T
    m_adds = copy(a.adds)
    for (k, v) in b.adds
        m_adds[k] = max(get(m_adds, k, UInt64(0)), v)
    end
    m_rems = copy(a.rems)
    for (k, v) in b.rems
        m_rems[k] = max(get(m_rems, k, UInt64(0)), v)
    end
    return ORSet{T}(m_adds, m_rems)
end

# 5. Presence Map (Cluster peer heartbeats)
struct PresenceMap
    peers::Dict{String, LWWRegister{Dict{String, Any}}}
end

PresenceMap() = PresenceMap(Dict{String, LWWRegister{Dict{String, Any}}}())

function update_presence!(pm::PresenceMap, peer_id::String, metadata::Dict{String, Any}, ts::Integer=time_ns())
    pm.peers[peer_id] = LWWRegister{Dict{String, Any}}(metadata, UInt64(ts), peer_id)
end

function merge_crdt(a::PresenceMap, b::PresenceMap)::PresenceMap
    merged = Dict{String, LWWRegister{Dict{String, Any}}}()
    for (k, reg) in a.peers
        merged[k] = reg
    end
    for (k, reg) in b.peers
        if haskey(merged, k)
            merged[k] = merge_crdt(merged[k], reg)
        else
            merged[k] = reg
        end
    end
    return PresenceMap(merged)
end

function get_active_presence(pm::PresenceMap, max_age_ns::Integer=60_000_000_000, now_ns::Integer=time_ns())::Dict{String, Dict{String, Any}}
    active = Dict{String, Dict{String, Any}}()
    for (peer, reg) in pm.peers
        if (now_ns >= reg.timestamp) && (now_ns - reg.timestamp <= max_age_ns)
            active[peer] = reg.val
        end
    end
    return active
end

end # module MaridCRDT
