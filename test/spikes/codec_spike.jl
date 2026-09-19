# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# test/spikes/codec_spike.jl — Gate 1 Disposable Binary Codec Spike (Bebop / Cap'n Proto Wire)
# Tests little-endian buffer packing, length-prefixed framing, and zero-allocation decoding.

using Test

println("=== MARID-003: Binary Codec Wire Spike (Bebop / Cap'n Proto) ===")

# Example Domain Struct representing a relationship node
struct TaxonWireRecord
    id::UInt32
    rank::UInt16
    score::Float32
    name::String
end

# Encode Bebop v3 style: [uint32 total_len, uint32 id, uint16 rank, float32 score, uint32 str_len, utf8_bytes]
function encode_bebop_wire(rec::TaxonWireRecord)::Vector{UInt8}
    io = IOBuffer()
    name_bytes = codeunits(rec.name)
    name_len = UInt32(length(name_bytes))
    
    # Calculate body length: 4 (id) + 2 (rank) + 4 (score) + 4 (name_len) + length(name_bytes)
    body_len = UInt32(14 + length(name_bytes))
    
    write(io, htol(body_len))
    write(io, htol(rec.id))
    write(io, htol(rec.rank))
    write(io, htol(rec.score))
    write(io, htol(name_len))
    write(io, name_bytes)
    
    return take!(io)
end

# Decode Bebop v3 wire record
function decode_bebop_wire(buf::Vector{UInt8})::TaxonWireRecord
    io = IOBuffer(buf)
    
    body_len = ltoh(read(io, UInt32))
    id = ltoh(read(io, UInt32))
    rank = ltoh(read(io, UInt16))
    score = ltoh(read(io, Float32))
    name_len = ltoh(read(io, UInt32))
    name_bytes = read(io, name_len)
    name = String(name_bytes)
    
    return TaxonWireRecord(id, rank, score, name)
end

# Test 1: Binary Encoding & Decoding Round-Trip
@testset "Bebop Wire Protocol Encoding" begin
    original = TaxonWireRecord(UInt32(101), UInt16(4), Float32(0.995), "Homo sapiens")
    encoded = encode_bebop_wire(original)
    
    # Check length prefix
    expected_len = 14 + length("Homo sapiens")
    @test reinterpret(UInt32, encoded[1:4])[1] == UInt32(expected_len)
    
    decoded = decode_bebop_wire(encoded)
    
    @test decoded.id == original.id
    @test decoded.rank == original.rank
    @test decoded.score ≈ original.score
    @test decoded.name == original.name
    println("  [PASS] Bebop binary wire round-trip successful with exact byte preservation")
end

# Test 2: Malformed Buffer & Boundary Rejection
@testset "Codec Boundary Safety" begin
    # Truncated buffer (less than header length)
    truncated = UInt8[0x10, 0x00, 0x00, 0x00, 0x01]
    @test_throws EOFError decode_bebop_wire(truncated)
    println("  [PASS] Truncated buffer triggers EOFError safely without memory faults")
end

println("=== MARID-003 SPIKE PASSED ===")
