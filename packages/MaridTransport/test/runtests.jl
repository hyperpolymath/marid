# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridTransport

@testset "MaridTransport Tests" begin
    # 1. SSE Formatting
    sse = format_sse_event(data="{\"score\":0.95}", event="progress", id="evt-1")
    @test occursin("id: evt-1\n", sse)
    @test occursin("event: progress\n", sse)
    @test occursin("data: {\"score\":0.95}\n\n", sse)
    
    # 2. HTTP Status line parsing
    (v, code, reason) = parse_http_status_line("HTTP/1.1 404 Not Found")
    @test v == "HTTP/1.1"
    @test code == 404
    @test reason == "Not Found"
end
