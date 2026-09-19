# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridLive

HTML-first live helpers for HTMX, Hotwire Turbo Streams, and Datastar over SSE/WebSocket.
Enables rich reactive UIs without mandatory JavaScript framework builds.
"""
module MaridLive

export hx_swap_oob, hx_trigger_header, hx_push_url_header, format_htmx_sse,
       turbo_stream, turbo_append, turbo_replace, turbo_update, turbo_remove,
       datastar_merge_fragments, datastar_merge_signals, datastar_remove_fragments

# 1. HTMX Helpers
"""
    hx_swap_oob(html::String, target_id::String; swap_mode::String="outerHTML") -> String

Wraps an HTML fragment with an out-of-band swap attribute for HTMX.
"""
function hx_swap_oob(html::String, target_id::String; swap_mode::String="outerHTML")::String
    return "<div id=\"$target_id\" hx-swap-oob=\"$swap_mode\">$html</div>"
end

"""
    hx_trigger_header(event_name::String; data::Union{Nothing, Dict}=nothing) -> Pair{String, String}

Produces the `HX-Trigger` response header.
"""
function hx_trigger_header(event_name::String; data::Union{Nothing, Dict}=nothing)::Pair{String, String}
    if data === nothing
        return "HX-Trigger" => event_name
    else
        # Simple JSON encoding for data
        kv = join(["\"$k\": \"$v\"" for (k, v) in data], ", ")
        return "HX-Trigger" => "{\"$event_name\": {$kv}}"
    end
end

function hx_push_url_header(url::String)::Pair{String, String}
    return "HX-Push-Url" => url
end

"""
    format_htmx_sse(event_name::String, html::String) -> String

Formats an SSE message specifically tailored for HTMX `hx-ext="sse"` listeners.
"""
function format_htmx_sse(event_name::String, html::String)::String
    # Multi-line HTML must have data: prefix on each line
    lines = split(html, '\n')
    data_lines = join(["data: $line" for line in lines], "\n")
    return "event: $event_name\n$data_lines\n\n"
end

# 2. Hotwire Turbo Streams
"""
    turbo_stream(action::String, target::String, html::String="") -> String

Formats a `<turbo-stream>` element.
Action can be: append, prepend, replace, update, remove, before, after.
"""
function turbo_stream(action::String, target::String, html::String="")::String
    if action == "remove"
        return "<turbo-stream action=\"remove\" target=\"$target\"></turbo-stream>"
    else
        return "<turbo-stream action=\"$action\" target=\"$target\"><template>$html</template></turbo-stream>"
    end
end

turbo_append(target::String, html::String) = turbo_stream("append", target, html)
turbo_replace(target::String, html::String) = turbo_stream("replace", target, html)
turbo_update(target::String, html::String) = turbo_stream("update", target, html)
turbo_remove(target::String) = turbo_stream("remove", target, "")

# 3. Datastar Helpers
"""
    datastar_merge_fragments(html::String; selector::String="", merge_mode::String="morph") -> String

Formats a Datastar `datastar-merge-fragments` SSE block.
"""
function datastar_merge_fragments(html::String; selector::String="", merge_mode::String="morph")::String
    buf = IOBuffer()
    println(buf, "event: datastar-merge-fragments")
    if !isempty(selector)
        println(buf, "data: selector $selector")
    end
    if merge_mode != "morph"
        println(buf, "data: mergeMode $merge_mode")
    end
    for line in split(html, '\n')
        println(buf, "data: fragments $line")
    end
    println(buf)
    return String(take!(buf))
end

"""
    datastar_merge_signals(signals::Dict{String, Any}; only_if_missing::Bool=false) -> String

Formats a Datastar `datastar-merge-signals` SSE block.
"""
function datastar_merge_signals(signals::Dict{String, Any}; only_if_missing::Bool=false)::String
    buf = IOBuffer()
    println(buf, "event: datastar-merge-signals")
    if only_if_missing
        println(buf, "data: onlyIfMissing true")
    end
    # Simple JSON encoding of signals dictionary
    entries = ["\"$k\": $(v isa String ? "\"$v\"" : string(v))" for (k, v) in signals]
    json_signals = "{" * join(entries, ", ") * "}"
    println(buf, "data: signals $json_signals\n")
    return String(take!(buf))
end

function datastar_remove_fragments(selector::String)::String
    return "event: datastar-remove-fragments\ndata: selector $selector\n\n"
end

end # module MaridLive
