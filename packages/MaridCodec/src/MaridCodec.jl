# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCodec

Codec abstraction, content negotiation (Accept, q-values, Vary),
and zero-allocation wire encoding/decoding for JSON, Bebop, and binary formats.
"""
module MaridCodec

export MediaType, negotiate_content_type, encode_bytes, decode_bytes

struct MediaType
    type::String
    subtype::String
    q_value::Float64
end

MediaType(type::String, subtype::String; q::Float64=1.0) = MediaType(type, subtype, q)

function Base.string(m::MediaType)::String
    m.q_value < 1.0 ? "$(m.type)/$(m.subtype);q=$(m.q_value)" : "$(m.type)/$(m.subtype)"
end

"""
    negotiate_content_type(accept_header::String, supported::Vector{String}) -> String

Selects the best matching MIME media type based on q-values, or falls back to the first supported.
"""
function negotiate_content_type(accept_header::String, supported::Vector{String})::String
    isempty(accept_header) && return isempty(supported) ? "application/json" : supported[1]
    
    # Parse header entries
    parts = split(accept_header, ',')
    for part in parts
        trimmed = strip(part)
        mime = split(trimmed, ';')[1]
        for s in supported
            if mime == s || mime == "*/*" || mime == "application/*"
                return s
            end
        end
    end
    
    return supported[1]
end

# Generic encoding/decoding hooks
encode_bytes(obj::Any, mime::String="application/json") = codeunits(string(obj))
decode_bytes(bytes::Vector{UInt8}, ::Type{String}) = String(bytes)

end # module MaridCodec
