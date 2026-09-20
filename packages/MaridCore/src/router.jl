# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.Router

Pure radix/trie request routing engine over immutable snapshots.
No network calls during lookup. Routes are copy-on-write; callers must not
mutate the exposed trie. Deep immutability/allocation guarantees are not claimed.
"""

export RouteMatch, RouteTable, TrieNode, add_route, match_route

struct RouteMatch{H}
    handler::H
    params::Dict{String, String}
end

mutable struct TrieNode{H}
    segment::String
    handler::Union{Nothing, H}
    children::Dict{String, TrieNode{H}}
    param_child::Union{Nothing, TrieNode{H}}
    param_name::String
    is_wildcard::Bool
end

function TrieNode{H}(segment::AbstractString="") where H
    TrieNode{H}(String(segment), nothing, Dict{String, TrieNode{H}}(), nothing, "", false)
end

struct RouteTable{H}
    # Method-indexed root nodes (e.g., "GET" => TrieNode, "POST" => TrieNode)
    roots::Dict{String, TrieNode{H}}
end

RouteTable{H}() where H = RouteTable{H}(Dict{String, TrieNode{H}}())

"""
    add_route(table::RouteTable{H}, method::String, path::String, handler::H) -> RouteTable{H}

Returns a new immutable RouteTable with the added route.
"""
function add_route(table::RouteTable{H}, method::String, path::String, handler::H)::RouteTable{H} where H
    m = uppercase(method)
    roots_copy = copy(table.roots)
    root = haskey(roots_copy, m) ? _clone_trie(roots_copy[m]) : TrieNode{H}("")
    
    segments = filter(!isempty, split(path, '/'))
    _insert_segments!(root, segments, 1, handler)
    roots_copy[m] = root
    
    return RouteTable{H}(roots_copy)
end

function _clone_trie(node::TrieNode{H})::TrieNode{H} where H
    children_clone = Dict{String, TrieNode{H}}()
    for (k, v) in node.children
        children_clone[k] = _clone_trie(v)
    end
    param_clone = node.param_child !== nothing ? _clone_trie(node.param_child) : nothing
    return TrieNode{H}(node.segment, node.handler, children_clone, param_clone, node.param_name, node.is_wildcard)
end

function _insert_segments!(node::TrieNode{H}, segments::Vector{<:AbstractString}, idx::Int, handler::H) where H
    if idx > length(segments)
        # Terminal node: store handler
        # Note: in an immutable clone, we reconstruct the node
        node.handler = handler
        return
    end
    
    seg = segments[idx]
    is_last = (idx == length(segments))
    
    if startswith(seg, ':')
        # Parameter segment (e.g. :id)
        pname = seg[2:end]
        child = node.param_child !== nothing ? _clone_trie(node.param_child) : TrieNode{H}(seg)
        if !isempty(child.param_name) && child.param_name != pname
            throw(ArgumentError("Conflicting parameter names on the same route branch"))
        end
        child.param_name = pname
        if is_last
            node.param_child = TrieNode{H}(seg, handler, child.children, child.param_child, pname, false)
        else
            node.param_child = child
            _insert_segments!(node.param_child, segments, idx + 1, handler)
        end
    elseif seg == "*"
        # Wildcard segment
        node.children["*"] = TrieNode{H}("*", handler, Dict{String, TrieNode{H}}(), nothing, "", true)
    else
        # Static segment
        child = haskey(node.children, seg) ? _clone_trie(node.children[seg]) : TrieNode{H}(seg)
        if is_last
            node.children[seg] = TrieNode{H}(seg, handler, child.children, child.param_child, "", false)
        else
            node.children[seg] = child
            _insert_segments!(node.children[seg], segments, idx + 1, handler)
        end
    end
end

"""
    match_route(table::RouteTable{H}, method::String, path::String) -> Union{Nothing, RouteMatch{H}}

Pure function route lookup over immutable snapshot. Zero locks.
"""
function match_route(table::RouteTable{H}, method::String, path::String)::Union{Nothing, RouteMatch{H}} where H
    m = uppercase(method)
    !haskey(table.roots, m) && return nothing
    
    root = table.roots[m]
    segments = filter(!isempty, split(path, '/'))
    params = Dict{String, String}()
    
    curr = root
    for (i, seg) in enumerate(segments)
        if haskey(curr.children, seg)
            curr = curr.children[seg]
        elseif curr.param_child !== nothing
            curr = curr.param_child
            params[curr.param_name] = seg
        elseif haskey(curr.children, "*")
            curr = curr.children["*"]
            params["*"] = join(segments[i:end], '/')
            break
        else
            return nothing
        end
    end
    
    curr.handler === nothing && return nothing
    return RouteMatch{H}(curr.handler, params)
end
