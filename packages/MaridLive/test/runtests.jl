# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridLive

@testset "MaridLive Complete Suite" begin
    # 1. HTMX Integration Helpers
    @testset "HTMX Helpers" begin
        # Out of band swap
        oob = hx_swap_oob("<span>Updated Node</span>", "node-42")
        @test occursin("id=\"node-42\"", oob)
        @test occursin("hx-swap-oob=\"outerHTML\"", oob)
        @test occursin("<span>Updated Node</span>", oob)
        
        # Headers
        h1 = hx_trigger_header("entityCreated")
        @test h1.first == "HX-Trigger"
        @test h1.second == "entityCreated"
        
        h2 = hx_trigger_header("scoreUpdated", data=Dict("score" => "42"))
        @test h2.first == "HX-Trigger"
        @test occursin("\"score\": \"42\"", h2.second)
        
        push_h = hx_push_url_header("/taxa/hominini")
        @test push_h.first == "HX-Push-Url"
        @test push_h.second == "/taxa/hominini"
        
        # SSE Wire Event for HTMX
        sse = format_htmx_sse("nodeChanged", "<div id=\"node\">Homo</div>")
        @test startswith(sse, "event: nodeChanged\n")
        @test occursin("data: <div id=\"node\">Homo</div>", sse)
        @test endswith(sse, "\n\n")
    end

    # 2. Hotwire Turbo Streams
    @testset "Turbo Streams" begin
        app = turbo_append("taxa-list", "<li>Pan troglodytes</li>")
        @test occursin("<turbo-stream action=\"append\" target=\"taxa-list\">", app)
        @test occursin("<template><li>Pan troglodytes</li></template>", app)
        
        rep = turbo_replace("status-box", "<div>Ready</div>")
        @test occursin("action=\"replace\"", rep)
        
        rem = turbo_remove("modal-1")
        @test rem == "<turbo-stream action=\"remove\" target=\"modal-1\"></turbo-stream>"
    end

    # 3. Datastar Reactive SSE Helpers
    @testset "Datastar Signals & Fragments" begin
        # Fragment merge
        frag = datastar_merge_fragments("<p id=\"msg\">Calculated</p>", selector="#msg", merge_mode="upsertAttributes")
        @test occursin("event: datastar-merge-fragments", frag)
        @test occursin("data: selector #msg", frag)
        @test occursin("data: mergeMode upsertAttributes", frag)
        @test occursin("data: fragments <p id=\"msg\">Calculated</p>", frag)
        
        # Signals merge
        sig = datastar_merge_signals(Dict{String, Any}("parsimony_score" => 3.5, "running" => true))
        @test occursin("event: datastar-merge-signals", sig)
        @test occursin("\"parsimony_score\": 3.5", sig)
        @test occursin("\"running\": true", sig)
        
        # Remove fragment
        rem_frag = datastar_remove_fragments("#stale-node")
        @test occursin("event: datastar-remove-fragments", rem_frag)
        @test occursin("data: selector #stale-node", rem_frag)
    end
end
