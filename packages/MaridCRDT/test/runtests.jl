# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridCRDT

@testset "MaridCRDT Complete Suite" begin
    # 1. G-Counter
    @testset "GCounter Properties" begin
        c1 = GCounter()
        c2 = GCounter()
        inc!(c1, "nodeA", 5)
        inc!(c2, "nodeB", 3)
        inc!(c1, "nodeB", 1)
        
        m1 = merge_crdt(c1, c2)
        m2 = merge_crdt(c2, c1)
        
        # Commutative
        @test value(m1) == value(m2)
        @test value(m1) == 8 # nodeA=5, nodeB=3
        
        # Idempotent
        m_idem = merge_crdt(m1, m1)
        @test value(m_idem) == value(m1)
    end

    # 2. PN-Counter
    @testset "PNCounter Operations" begin
        pnc1 = PNCounter()
        pnc2 = PNCounter()
        
        inc!(pnc1, "nodeA", 10)
        dec!(pnc1, "nodeA", 3)
        @test value(pnc1) == 7
        
        dec!(pnc2, "nodeB", 2)
        inc!(pnc2, "nodeA", 1)
        
        merged = merge_crdt(pnc1, pnc2)
        # pos: nodeA=10, nodeB=0 -> 10. neg: nodeA=3, nodeB=2 -> 5. Net = 5
        @test value(merged) == 5
    end

    # 3. LWW-Register
    @testset "LWWRegister Convergence" begin
        r1 = LWWRegister("initial")
        r2 = LWWRegister("initial")
        
        r1 = set_value!(r1, "state_A", 100, "nodeA")
        r2 = set_value!(r2, "state_B", 200, "nodeB")
        
        m = merge_crdt(r1, r2)
        @test value(m) == "state_B"
        
        # Tie-breaker on identical timestamps
        r3 = set_value!(r1, "state_A2", 300, "nodeA")
        r4 = set_value!(r2, "state_B2", 300, "nodeB")
        m_tie = merge_crdt(r3, r4)
        @test value(m_tie) == "state_B2" # "nodeB" > "nodeA"
    end

    # 4. OR-Set Concurrent Add-Wins
    @testset "ORSet Add-Wins Semantics" begin
        s1 = ORSet{String}()
        s2 = ORSet{String}()
        
        # Node 1 adds "taxon_1"
        tag1 = add_element!(s1, "taxon_1", "tag1", 100)
        
        # Node 2 syncs s1, then removes "taxon_1"
        s2 = merge_crdt(s1, s2)
        remove_element!(s2, "taxon_1", 200)
        @test !has_element(s2, "taxon_1")
        
        # Meanwhile Node 1 concurrently re-adds "taxon_1" with newer timestamp
        tag2 = add_element!(s1, "taxon_1", "tag2", 300)
        
        # Merge s1 and s2: newer add wins over older remove
        m = merge_crdt(s1, s2)
        @test has_element(m, "taxon_1")
        @test "taxon_1" in read_elements(m)
    end

    # 5. PresenceMap
    @testset "PresenceMap Cluster Heartbeats" begin
        pm1 = PresenceMap()
        pm2 = PresenceMap()
        
        ts = 1_000_000_000
        update_presence!(pm1, "node-1", Dict{String, Any}("role" => "worker", "load" => 0.15), ts)
        update_presence!(pm2, "node-2", Dict{String, Any}("role" => "leader", "load" => 0.05), ts)
        
        merged = merge_crdt(pm1, pm2)
        active = get_active_presence(merged, 10_000_000_000, ts + 1_000_000)
        @test length(active) == 2
        @test active["node-1"]["role"] == "worker"
        @test active["node-2"]["role"] == "leader"
        
        # Stale peer expired
        stale = get_active_presence(merged, 500_000, ts + 1_000_000)
        @test isempty(stale)
    end

    # 6. Network Partition Simulator (Strong Eventual Consistency)
    @testset "Partition Simulator (SEC Verification)" begin
        # 3 Nodes in cluster
        n1_counter = PNCounter()
        n2_counter = PNCounter()
        n3_counter = PNCounter()
        
        n1_set = ORSet{String}()
        n2_set = ORSet{String}()
        n3_set = ORSet{String}()
        
        # Partition begins: Group A = {N1, N2}, Group B = {N3}
        # Mutations on Group A
        inc!(n1_counter, "n1", 10)
        inc!(n2_counter, "n2", 5)
        add_element!(n1_set, "Clade_A", "t_a", 100)
        
        # Sync within Group A
        n1_counter = merge_crdt(n1_counter, n2_counter)
        n2_counter = merge_crdt(n2_counter, n1_counter)
        n2_set = merge_crdt(n2_set, n1_set)
        
        # Isolated mutations on Group B (N3)
        dec!(n3_counter, "n3", 2)
        add_element!(n3_set, "Clade_B", "t_b", 120)
        
        # Partition heals: Nodes merge across partition in arbitrary orders
        # Order 1: N1 merges N3
        n1_final_c = merge_crdt(n1_counter, n3_counter)
        n1_final_s = merge_crdt(n1_set, n3_set)
        
        # Order 2: N3 merges N2 (which already had N1)
        n3_final_c = merge_crdt(n3_counter, n2_counter)
        n3_final_s = merge_crdt(n3_set, n2_set)
        
        # Order 3: N2 merges N3
        n2_final_c = merge_crdt(n2_counter, n3_counter)
        n2_final_s = merge_crdt(n2_set, n3_set)
        
        # SEC Assertion: ALL nodes reach identical state regardless of merge order
        @test value(n1_final_c) == value(n2_final_c) == value(n3_final_c) == 13 # 10 + 5 - 2
        @test read_elements(n1_final_s) == read_elements(n2_final_s) == read_elements(n3_final_s)
        @test "Clade_A" in read_elements(n1_final_s)
        @test "Clade_B" in read_elements(n1_final_s)
    end
end
