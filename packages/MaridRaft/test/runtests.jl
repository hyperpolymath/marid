# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridRaft

@testset "MaridRaft Complete Suite" begin
    # 1. State Transitions & RequestVote
    @testset "RequestVote Logic" begin
        n1 = RaftNode("node-1", ["node-2", "node-3"])
        
        # Candidate requesting vote with higher term
        args = RequestVoteArgs(1, "node-2", 0, 0)
        reply = handle_request_vote(n1, args)
        @test reply.vote_granted == true
        @test n1.voted_for == "node-2"
        @test n1.current_term == 1
        
        # Second candidate requests vote in same term -> rejected
        args2 = RequestVoteArgs(1, "node-3", 0, 0)
        reply2 = handle_request_vote(n1, args2)
        @test reply2.vote_granted == false
        
        # Candidate with lower term -> rejected
        args_stale = RequestVoteArgs(0, "node-3", 0, 0)
        reply_stale = handle_request_vote(n1, args_stale)
        @test reply_stale.vote_granted == false
    end

    # 2. AppendEntries Log Replication
    @testset "AppendEntries Consistency" begin
        follower = RaftNode("node-2", ["node-1"])
        
        # Append initial entry
        entry1 = RaftEntry(1, 1, Dict{String, Any}("key1" => "val1"))
        args = AppendEntriesArgs(1, "node-1", 0, 0, [entry1], 0)
        rep = handle_append_entries(follower, args)
        @test rep.success == true
        @test length(follower.log) == 1
        
        # Commit entry
        args_commit = AppendEntriesArgs(1, "node-1", 1, 1, RaftEntry[], 1)
        rep_commit = handle_append_entries(follower, args_commit)
        @test follower.commit_index == 1
        @test follower.state_machine["key1"] == "val1"
    end

    # 3. 3-Node Cluster Election & Replication
    @testset "3-Node Cluster Election & Quorum" begin
        n1 = RaftNode("n1", ["n2", "n3"])
        n2 = RaftNode("n2", ["n1", "n3"])
        n3 = RaftNode("n3", ["n1", "n2"])
        cluster = Dict("n1" => n1, "n2" => n2, "n3" => n3)
        
        # N1 starts election
        elected = start_election!(n1, cluster)
        @test elected == true
        @test n1.role == Leader
        @test n1.current_term == 1
        
        # Leader replicates command
        ok = replicate_entry!(n1, cluster, Dict{String, Any}("cluster_state" => "active"))
        @test ok == true
        @test n1.commit_index == 1
        @test n1.state_machine["cluster_state"] == "active"
        @test n2.state_machine["cluster_state"] == "active"
        @test n3.state_machine["cluster_state"] == "active"
    end

    # 4. Partition Resistance
    @testset "Network Partition Quorum Isolation" begin
        n1 = RaftNode("n1", ["n2", "n3"])
        n2 = RaftNode("n2", ["n1", "n3"])
        n3 = RaftNode("n3", ["n1", "n2"])
        
        # Establish N1 as leader
        start_election!(n1, Dict("n1" => n1, "n2" => n2, "n3" => n3))
        @test n1.role == Leader
        
        # Partition occurs: Majority {n1, n2}, Minority {n3}
        majority_cluster = Dict("n1" => n1, "n2" => n2)
        minority_cluster = Dict("n3" => n3)
        
        # Majority commits successfully
        res = replicate_entry!(n1, majority_cluster, Dict{String, Any}("quorum_key" => "replicated"))
        @test res == true
        @test n1.state_machine["quorum_key"] == "replicated"
        @test n2.state_machine["quorum_key"] == "replicated"
        
        # Isolated N3 cannot commit without quorum
        start_election!(n3, minority_cluster) # Cannot reach majority of 2/3
        @test n3.role == Follower
    end
end
