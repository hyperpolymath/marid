# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridCodec

@testset "MaridCodec Tests" begin
    supported = ["application/json", "application/cbor", "application/x-bebop"]
    
    # 1. Content negotiation
    @test negotiate_content_type("application/cbor, application/json;q=0.5", supported) == "application/cbor"
    @test negotiate_content_type("*/*", supported) == "application/json"
    @test_throws ArgumentError negotiate_content_type("text/html", supported)
    
    # 2. String conversion
    mt = MediaType("application", "json", q=0.8)
    @test string(mt) == "application/json;q=0.8"
end

@testset "Native JSON and quality negotiation" begin
    bytes = encode_bytes(Dict("quote" => "a\"b", "n" => 7, "null" => nothing))
    parsed = decode_json(bytes)
    @test parsed.quote == "a\"b"
    @test parsed.n == 7
    @test parsed.null === nothing
    @test_throws Exception decode_json(UInt8[0x7b])
    @test_throws ArgumentError encode_bytes(1, "application/cbor")
    types = ["application/json", "text/plain"]
    @test negotiate_content_type("application/json;q=0.1, text/plain;q=0.9", types) == "text/plain"
    @test negotiate_content_type("application/json;q=0, */*;q=1", types) == "text/plain"
    @test_throws ArgumentError negotiate_content_type("application/json;q=0, */*;q=1", ["application/json"])
    @test_throws ArgumentError negotiate_content_type("application/json;q=9", types)
    @test_throws ArgumentError negotiate_content_type("application/json;profile=x", types)
    @test_throws ArgumentError negotiate_content_type("", String[])
    @test negotiate_content_type("text/*", types) == "text/plain"
end
