# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.Streaming

Bounded streaming seam (`Stream{T}`) with backpressure, cancellation hooks,
and slow-consumer protection.
"""

export Stream, push_item!, close_stream!, is_closed, collect_stream

struct Stream{T}
    channel::Channel{T}
    context::CallContext
    closed::Ref{Bool}
end

function Stream{T}(capacity::Int, ctx::CallContext) where T
    c = Channel{T}(capacity)
    return Stream{T}(c, ctx, Ref(false))
end

# Default capacity of 64 bounded items
Stream{T}(ctx::CallContext) where T = Stream{T}(64, ctx)

"""
    push_item!(stream::Stream{T}, item::T)

Pushes an item into the stream. Throws error if stream is cancelled or expired.
"""
function push_item!(stream::Stream{T}, item::T) where T
    check_deadline(stream.context)
    if is_cancelled(stream.context)
        close_stream!(stream)
        error("Cannot push item: stream cancelled by context.")
    end
    put!(stream.channel, item)
end

"""
    close_stream!(stream::Stream)

Safely closes the underlying channel.
"""
function close_stream!(stream::Stream)
    if !stream.closed[]
        stream.closed[] = true
        close(stream.channel)
    end
end

is_closed(stream::Stream) = stream.closed[] || !isopen(stream.channel)

# Iteration interface
Base.iterate(stream::Stream, state...) = iterate(stream.channel, state...)
Base.IteratorSize(::Type{<:Stream}) = Base.SizeUnknown()
Base.eltype(::Type{Stream{T}}) where T = T

"""
    collect_stream(stream::Stream{T}) -> Vector{T}

Drains all items from the stream into an array.
"""
function collect_stream(stream::Stream{T})::Vector{T} where T
    items = T[]
    for item in stream
        push!(items, item)
    end
    return items
end
