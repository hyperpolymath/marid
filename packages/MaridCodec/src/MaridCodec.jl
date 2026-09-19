# SPDX-License-Identifier: MPL-2.0
"""JSON3 wire codec and HTTP content negotiation. Binary codec extensions remain unsupported."""
module MaridCodec
using JSON3
export MediaType, negotiate_content_type, encode_bytes, decode_bytes, decode_json

struct MediaType
    type::String
    subtype::String
    q_value::Float64
end
MediaType(type::String, subtype::String; q::Float64=1.0) = MediaType(type, subtype, q)
Base.string(m::MediaType) = m.q_value < 1.0 ? "$(m.type)/$(m.subtype);q=$(m.q_value)" : "$(m.type)/$(m.subtype)"

"""
    negotiate_content_type(accept, supported) -> String

Return the best acceptable supported media type. Throw `ArgumentError` when no
representations are supported or the header permits none of them.
More-specific ranges override wildcard q-values. q=0 excludes that representation.
Tie-break by supported order. Parameterized media ranges are not supported in this
initial JSON slice and never match a bare representation accidentally.
"""
function negotiate_content_type(accept::String, supported::Vector{String})::String
    isempty(supported) && throw(ArgumentError("No supported representations"))
    isempty(strip(accept)) && return first(supported)
    ranges = Tuple{String,Float64,Int}[]
    for item in split(accept, ',')
        parts = strip.(split(lowercase(item), ';'))
        mime = parts[1]
        occursin(r"^(\*/\*|[a-z0-9!#$&^_.+-]+/(\*|[a-z0-9!#$&^_.+-]+))$", mime) || continue
        quality = 1.0
        usable = true
        seen_q = false
        for parameter in parts[2:end]
            pair = strip.(split(parameter, '='; limit=2))
            if length(pair) == 2 && pair[1] == "q" && !seen_q
                seen_q = true
                occursin(r"^(0(?:\.[0-9]{0,3})?|1(?:\.0{0,3})?)$", pair[2]) || (usable = false; break)
                quality = parse(Float64, pair[2])
            elseif !seen_q
                # No media parameters are offered by this slice.
                usable = false
                break
            end
            # Accept extensions after q do not constrain the media type.
        end
        usable || continue
        specificity = mime == "*/*" ? 0 : endswith(mime, "/*") ? 1 : 2
        push!(ranges, (String(mime), quality, specificity))
    end
    winner = nothing
    best_q = 0.0
    for candidate in supported
        type = first(split(lowercase(candidate), '/'))
        matches = filter(r -> r[1] in (lowercase(candidate), "$type/*", "*/*"), ranges)
        isempty(matches) && continue
        specificity = maximum(r[3] for r in matches)
        q = maximum(r[2] for r in matches if r[3] == specificity)
        if q > best_q
            best_q = q
            winner = candidate
        end
    end
    winner === nothing && throw(ArgumentError("No acceptable representation"))
    return winner
end

"""
    encode_bytes(value, mime="application/json") -> Vector{UInt8}

Encode `value` as UTF-8 JSON bytes. Throw `ArgumentError` for unsupported codecs.
"""
function encode_bytes(value, mime::String="application/json")::Vector{UInt8}
    mime == "application/json" || throw(ArgumentError("Unsupported codec: $mime"))
    return Vector{UInt8}(codeunits(JSON3.write(value)))
end

# Explicit JSON decoding; no eval or Julia object deserialization.
"""
    decode_json(bytes)

Parse UTF-8 JSON bytes into the corresponding JSON3 value. Invalid JSON propagates
the parser error.
"""
decode_json(bytes::AbstractVector{UInt8}) = JSON3.read(bytes)
decode_bytes(bytes::Vector{UInt8}, ::Type{String}) = String(bytes)
end
