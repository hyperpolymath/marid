# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridTransport

@testset "MaridTransport Complete Suite" begin
    # 1. SSE Formatting
    @testset "Server-Sent Events Framing" begin
        evt = format_sse_event(data="payload-data", event="update", id="101")
        @test occursin("id: 101\n", evt)
        @test occursin("event: update\n", evt)
        @test occursin("data: payload-data\n", evt)
        @test endswith(evt, "\n\n")
    end

    # 2. HTTP Status Line Parsing
    @testset "HTTP Status Line Parsing" begin
        ver, code, msg = parse_http_status_line("HTTP/1.1 200 OK")
        @test ver == "HTTP/1.1"
        @test code == 200
        @test msg == "OK"
        
        _, code_nf, msg_nf = parse_http_status_line("HTTP/1.1 404 Not Found")
        @test code_nf == 404
        @test msg_nf == "Not Found"
    end

    # 3. gRPC Length-Delimited Framing
    @testset "gRPC Binary Message Framing" begin
        payload = UInt8[0x08, 0x96, 0x01] # Proto varint message
        framed = frame_grpc_message(payload)
        
        # 1 byte flag + 4 bytes length + 3 bytes payload = 8 bytes
        @test length(framed) == 8
        @test framed[1] == GRPC_FLAG_DATA
        @test framed[2:5] == UInt8[0x00, 0x00, 0x00, 0x03]
        @test framed[6:8] == payload
        
        # Unframe
        unframed = unframe_grpc_messages(framed)
        @test length(unframed) == 1
        @test unframed[1].flag == GRPC_FLAG_DATA
        @test unframed[1].data == payload
    end

    # 4. Multi-Message gRPC Stream Unframing
    @testset "Multi-Message Stream Unframing" begin
        msg1 = UInt8[0x01, 0x02]
        msg2 = UInt8[0x03, 0x04, 0x05]
        
        stream_bytes = vcat(
            frame_grpc_message(msg1),
            frame_grpc_message(msg2, compressed=true)
        )
        
        parsed = unframe_grpc_messages(stream_bytes)
        @test length(parsed) == 2
        @test parsed[1].flag == GRPC_FLAG_DATA
        @test parsed[1].data == msg1
        @test parsed[2].flag == GRPC_FLAG_COMPRESSED
        @test parsed[2].data == msg2
    end

    # 5. gRPC-Web Trailers & Status Codes
    @testset "gRPC-Web Trailers & Status Codes" begin
        @test grpc_status_code(:OK) == 0
        @test grpc_status_code(:NOT_FOUND) == 5
        @test grpc_status_code(:INTERNAL) == 13
        
        trailer_frame = format_grpc_web_trailers(0, "OK")
        @test trailer_frame[1] == GRPC_FLAG_WEB_TRAILER # 0x80
        
        unframed_trailers = unframe_grpc_messages(trailer_frame)
        @test length(unframed_trailers) == 1
        @test unframed_trailers[1].flag == GRPC_FLAG_WEB_TRAILER
        
        txt = String(unframed_trailers[1].data)
        @test occursin("grpc-status: 0", txt)
        @test occursin("grpc-message: OK", txt)
    end
end
