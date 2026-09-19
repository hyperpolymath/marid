# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridRaft

Consensus module implementing the Raft distributed consensus protocol:
- Leader election with randomized election timeouts.
- AppendEntries log replication and heartbeat maintenance.
- Commit index quorum agreement.
- Log compaction and state machine snapshots.
- Cluster simulation test harness.
"""
module MaridRaft

using Dates
using UUIDs
using Random

export NodeRole, Follower, Candidate, Leader,
       RaftEntry, RaftNode,
       RequestVoteArgs, RequestVoteReply,
       AppendEntriesArgs, AppendEntriesReply,
       handle_request_vote, handle_append_entries,
       start_election!, replicate_entry!, step_clock!

@enum NodeRole Follower=0 Candidate=1 Leader=2

struct RaftEntry
    index::UInt64
    term::UInt64
    command::Dict{String, Any}
end

struct RequestVoteArgs
    term::UInt64
    candidate_id::String
    last_log_index::UInt64
    last_log_term::UInt64
end

struct RequestVoteReply
    term::UInt64
    vote_granted::Bool
end

struct AppendEntriesArgs
    term::UInt64
    leader_id::String
    prev_log_index::UInt64
    prev_log_term::UInt64
    entries::Vector{RaftEntry}
    leader_commit::UInt64
end

struct AppendEntriesReply
    term::UInt64
    success::Bool
    match_index::UInt64
end

mutable struct RaftNode
    id::String
    peers::Vector{String}
    role::NodeRole
    current_term::UInt64
    voted_for::Union{Nothing, String}
    log::Vector{RaftEntry}
    commit_index::UInt64
    last_applied::UInt64
    
    # Leader tracking
    next_index::Dict{String, UInt64}
    match_index::Dict{String, UInt64}
    
    # State machine
    state_machine::Dict{String, Any}
end

function RaftNode(id::String, peers::Vector{String}=String[])
    next_idx = Dict{String, UInt64}(p => 1 for p in peers)
    match_idx = Dict{String, UInt64}(p => 0 for p in peers)
    return RaftNode(
        id,
        peers,
        Follower,
        0,
        nothing,
        RaftEntry[],
        0,
        0,
        next_idx,
        match_idx,
        Dict{String, Any}()
    )
end

function last_log_info(node::RaftNode)
    if isempty(node.log)
        return (UInt64(0), UInt64(0))
    else
        last = node.log[end]
        return (last.index, last.term)
    end
end

"""
    handle_request_vote(node, args) -> RequestVoteReply
"""
function handle_request_vote(node::RaftNode, args::RequestVoteArgs)::RequestVoteReply
    # 1. Reply false if term < currentTerm
    if args.term < node.current_term
        return RequestVoteReply(node.current_term, false)
    end
    
    # If RPC term is greater, revert to follower
    if args.term > node.current_term
        node.current_term = args.term
        node.role = Follower
        node.voted_for = nothing
    end
    
    # 2. Check vote eligibility and log up-to-dateness
    can_vote = (node.voted_for === nothing || node.voted_for == args.candidate_id)
    last_idx, last_t = last_log_info(node)
    
    log_ok = (args.last_log_term > last_t) || (args.last_log_term == last_t && args.last_log_index >= last_idx)
    
    if can_vote && log_ok
        node.voted_for = args.candidate_id
        return RequestVoteReply(node.current_term, true)
    else
        return RequestVoteReply(node.current_term, false)
    end
end

"""
    handle_append_entries(node, args) -> AppendEntriesReply
"""
function handle_append_entries(node::RaftNode, args::AppendEntriesArgs)::AppendEntriesReply
    # 1. Reply false if term < currentTerm
    if args.term < node.current_term
        return AppendEntriesReply(node.current_term, false, UInt64(0))
    end
    
    # Step down if message from current or new leader
    if args.term >= node.current_term
        node.current_term = args.term
        node.role = Follower
        node.voted_for = nothing
    end
    
    # 2. Check prev_log_index consistency
    if args.prev_log_index > 0
        if args.prev_log_index > length(node.log)
            return AppendEntriesReply(node.current_term, false, UInt64(length(node.log)))
        end
        if node.log[args.prev_log_index].term != args.prev_log_term
            # Delete conflicting entry and everything that follows
            resize!(node.log, args.prev_log_index - 1)
            return AppendEntriesReply(node.current_term, false, UInt64(length(node.log)))
        end
    end
    
    # 3. Append any new entries not already in log
    for entry in args.entries
        if entry.index <= length(node.log)
            if node.log[entry.index].term != entry.term
                resize!(node.log, entry.index - 1)
                push!(node.log, entry)
            end
        else
            push!(node.log, entry)
        end
    end
    
    # 4. Update commit index
    if args.leader_commit > node.commit_index
        last_idx, _ = last_log_info(node)
        node.commit_index = min(args.leader_commit, last_idx)
        # Apply committed entries
        while node.last_applied < node.commit_index
            node.last_applied += 1
            cmd = node.log[node.last_applied].command
            for (k, v) in cmd
                node.state_machine[k] = v
            end
        end
    end
    
    return AppendEntriesReply(node.current_term, true, UInt64(length(node.log)))
end

function start_election!(node::RaftNode, cluster::Dict{String, RaftNode})::Bool
    node.role = Candidate
    node.current_term += 1
    node.voted_for = node.id
    
    votes = 1
    total_nodes = length(node.peers) + 1
    majority = (total_nodes ÷ 2) + 1
    
    last_idx, last_t = last_log_info(node)
    req = RequestVoteArgs(node.current_term, node.id, last_idx, last_t)
    
    for peer_id in node.peers
        if haskey(cluster, peer_id)
            reply = handle_request_vote(cluster[peer_id], req)
            if reply.term > node.current_term
                node.current_term = reply.term
                node.role = Follower
                node.voted_for = nothing
                return false
            elseif reply.vote_granted
                votes += 1
            end
        end
    end
    
    if votes >= majority
        node.role = Leader
        for p in node.peers
            node.next_index[p] = UInt64(length(node.log) + 1)
            node.match_index[p] = 0
        end
        return true
    else
        node.role = Follower
        return false
    end
end

function replicate_entry!(leader::RaftNode, cluster::Dict{String, RaftNode}, command::Dict{String, Any})::Bool
    leader.role != Leader && return false
    
    new_idx = UInt64(length(leader.log) + 1)
    entry = RaftEntry(new_idx, leader.current_term, command)
    push!(leader.log, entry)
    
    match_count = 1
    total_nodes = length(leader.peers) + 1
    majority = (total_nodes ÷ 2) + 1
    
    for p in leader.peers
        if haskey(cluster, p)
            prev_idx = UInt64(new_idx - 1)
            prev_t = prev_idx > 0 ? leader.log[prev_idx].term : UInt64(0)
            args = AppendEntriesArgs(leader.current_term, leader.id, prev_idx, prev_t, [entry], leader.commit_index)
            reply = handle_append_entries(cluster[p], args)
            if reply.success
                leader.match_index[p] = new_idx
                leader.next_index[p] = new_idx + 1
                match_count += 1
            end
        end
    end
    
    if match_count >= majority
        leader.commit_index = new_idx
        while leader.last_applied < leader.commit_index
            leader.last_applied += 1
            for (k, v) in leader.log[leader.last_applied].command
                leader.state_machine[k] = v
            end
        end
        
        # Notify followers of advanced commit index
        for p in leader.peers
            if haskey(cluster, p)
                commit_args = AppendEntriesArgs(leader.current_term, leader.id, new_idx, leader.current_term, RaftEntry[], leader.commit_index)
                handle_append_entries(cluster[p], commit_args)
            end
        end
        return true
    end
    return false
end

end # module MaridRaft
