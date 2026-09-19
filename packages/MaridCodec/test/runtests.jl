# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridCodec

@testset "MaridCodec Tests" begin
    supported = ["application/json", "application/cbor", "application/x-bebop"]
    
    # 1. Content negotiation
    @test negotiate_content_type("application/cbor, application/json;q=0.5", supported) == "application/cbor"
    @test negotiate_content_type("*/*", supported) == "application/json"
    @test negotiate_content_type("text/html", supported) == "application/json"
    
    # 2. String conversion
    mt = MediaType("application", "json", q=0.8)
    @test string(mt) == "application/json;q=0.8"
end
