# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridTransport.GRPC

Length-delimited binary framing for gRPC, gRPC-Web, and Connect protocol streams.
"""

export frame_grpc_message, unframe_grpc_messages, format_grpc_web_trailers,
       grpc_status_code, GRPC_FLAG_DATA, GRPC_FLAG_COMPRESSED, GRPC_FLAG_WEB_TRAILER, CONNECT_FLAG_END_STREAM

const GRPC_FLAG_DATA = 0x00
const GRPC_FLAG_COMPRESSED = 0x01
const CONNECT_FLAG_END_STREAM = 0x02
const GRPC_FLAG_WEB_TRAILER = 0x80

"""
    frame_grpc_message(payload::Vector{UInt8}; compressed::Bool=false, flag::UInt8=0x00) -> Vector{UInt8}

Encodes binary payload into a 5-byte length-prefixed gRPC frame:
[1-byte flag] [4-byte big-endian length] [payload bytes...]
"""
function frame_grpc_message(payload::Vector{UInt8}; compressed::Bool=false, flag::Union{Nothing, UInt8}=nothing)::Vector{UInt8}
    f = flag !== nothing ? flag : (compressed ? GRPC_FLAG_COMPRESSED : GRPC_FLAG_DATA)
    len = UInt32(length(payload))
    header = UInt8[
        f,
        UInt8((len >> 24) & 0xff),
        UInt8((len >> 16) & 0xff),
        UInt8((len >> 8) & 0xff),
        UInt8(len & 0xff)
    ]
    return vcat(header, payload)
end

"""
    unframe_grpc_messages(bytes::Vector{UInt8}) -> Vector{@NamedTuple{flag::UInt8, data::Vector{UInt8}}}

Parses a buffer containing one or more length-prefixed gRPC frames.
"""
function unframe_grpc_messages(bytes::Vector{UInt8})
    frames = @NamedTuple{flag::UInt8, data::Vector{UInt8}}[]
    offset = 1
    total = length(bytes)
    
    while offset + 4 <= total
        flag = bytes[offset]
        len = (UInt32(bytes[offset + 1]) << 24) |
              (UInt32(bytes[offset + 2]) << 16) |
              (UInt32(bytes[offset + 3]) << 8)  |
              UInt32(bytes[offset + 4])
        
        offset += 5
        if offset + len - 1 > total
            error("Truncated gRPC frame: expected $len bytes, available $(total - offset + 1)")
        end
        
        data = bytes[offset : offset + len - 1]
        push!(frames, (flag=flag, data=data))
        offset += len
    end
    
    return frames
end

"""
    grpc_status_code(status::Symbol) -> Int

Maps canonical status symbols to standard gRPC status codes.
"""
function grpc_status_code(status::Symbol)::Int
    status == :OK && return 0
    status == :CANCELLED && return 1
    status == :UNKNOWN && return 2
    status == :INVALID_ARGUMENT && return 3
    status == :DEADLINE_EXCEEDED && return 4
    status == :NOT_FOUND && return 5
    status == :ALREADY_EXISTS && return 6
    status == :PERMISSION_DENIED && return 7
    status == :RESOURCE_EXHAUSTED && return 8
    status == :FAILED_PRECONDITION && return 9
    status == :ABORTED && return 10
    status == :OUT_OF_RANGE && return 11
    status == :UNIMPLEMENTED && return 12
    status == :INTERNAL && return 13
    status == :UNAVAILABLE && return 14
    status == :DATA_LOSS && return 15
    status == :UNAUTHENTICATED && return 16
    return 2 # default to UNKNOWN
end

"""
    format_grpc_web_trailers(status::Int=0, message::String="OK") -> Vector{UInt8}

Encodes gRPC-Web trailer frame (flag 0x80) containing status and message.
"""
function format_grpc_web_trailers(status::Int=0, message::String="OK")::Vector{UInt8}
    trailers_str = "grpc-status: $status\r\ngrpc-message: $message\r\n"
    payload = Vector{UInt8}(codeunits(trailers_str))
    return frame_grpc_message(payload, flag=GRPC_FLAG_WEB_TRAILER)
end
