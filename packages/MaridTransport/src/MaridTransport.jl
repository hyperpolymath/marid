# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridTransport

Transport seam abstraction for Marid: HTTP/1.1 framing, Server-Sent Events (SSE),
and WebSocket protocol upgrades.
"""
module MaridTransport

using Sockets

export format_sse_event, parse_http_status_line

"""
    format_sse_event(; data::String, event::String="", id::String="") -> String

Formats a Server-Sent Event stream chunk according to the W3C SSE standard.
"""
function format_sse_event(; data::String, event::String="", id::String="")::String
    io = IOBuffer()
    !isempty(id) && write(io, "id: $id\n")
    !isempty(event) && write(io, "event: $event\n")
    for line in split(data, '\n')
        write(io, "data: $line\n")
    end
    write(io, "\n")
    return String(take!(io))
end

"""
    parse_http_status_line(line::String) -> (String, Int, String)

Parses standard HTTP status line `HTTP/1.1 200 OK`.
"""
function parse_http_status_line(line::String)
    parts = split(strip(line), ' ', limit=3)
    length(parts) < 2 && error("Invalid HTTP status line")
    version = parts[1]
    status = parse(Int, parts[2])
    reason = length(parts) >= 3 ? parts[3] : ""
    return (version, status, reason)
end

end # module MaridTransport
