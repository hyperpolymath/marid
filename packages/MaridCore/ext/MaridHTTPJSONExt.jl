# SPDX-License-Identifier: MPL-2.0
module MaridHTTPJSONExt
using MaridCore, MaridCodec, MaridTransport
import MaridCore: serve_json

header(req, name, default="") = join([v for (k,v) in req.headers if lowercase(k) == name], ",") |> x -> isempty(x) ? default : x
function response(status, value; headers=Pair{String,String}[], problem=false)
    TransportResponse(status, vcat([
        "Content-Type" => (problem ? "application/problem+json" : "application/json"),
        "Vary" => "Accept", "X-Content-Type-Options" => "nosniff"
    ], headers), encode_bytes(value))
end
problem(status, title; headers=Pair{String,String}[]) = response(status,
    Dict("type"=>"about:blank", "title"=>title, "status"=>status); headers, problem=true)

function handle_json(app, req, timeout_ms, max_response_bytes)
    ctx = create_context(; timeout_ms) # Never treat X-Trust-Level as a verified principal.
    headers = ["X-Request-ID" => ctx.trace_id]
    input = nothing
    output = nothing
    try
        app.is_draining && return problem(503, "Service Unavailable"; headers)
        try
            negotiate_content_type(header(req, "accept"), ["application/json"])
        catch e
            e isa ArgumentError || rethrow()
            return problem(406, "Not Acceptable"; headers)
        end
        route = match_route(app.routes, req.method, req.path)
        if route === nothing
            allowed = sort!([m for m in keys(app.routes.roots) if match_route(app.routes, m, req.path) !== nothing])
            isempty(allowed) && return problem(404, "Not Found"; headers)
            return problem(405, "Method Not Allowed"; headers=vcat(headers, ["Allow"=>join(allowed, ", ")]))
        end
        value = nothing
        if !isempty(req.body)
            lowercase(strip(first(split(header(req, "content-type"), ';')))) == "application/json" ||
                return problem(415, "Unsupported Media Type"; headers)
            value = try
                decode_json(req.body)
            catch
                return problem(400, "Invalid JSON"; headers)
            end
        end
        input = Stream{Any}(1, ctx)
        push_item!(input, value)
        close_stream!(input)
        output = dispatch_call(app, ctx, req.method, req.path, input)
        output isa Stream || error("Unary handler must return a Stream")
        is_closed(output) || error("Unary handler must close its output before returning")
        items = collect_stream(output)
        length(items) == 1 || error("Unary handler must return exactly one item")
        check_deadline(ctx)
        result = response(200, only(items); headers)
        length(result.body) <= max_response_bytes || return problem(500, "Response limit exceeded"; headers)
        return result
    catch error
        if error isa MaridError && !(error isa InternalError)
            return response(status_code(error), problem_details(error); headers, problem=true)
        end
        # Never serialize exception messages, stacks or input payloads for 500s.
        return problem(500, "Internal Server Error"; headers)
    finally
        input !== nothing && close_stream!(input)
        output isa Stream && close_stream!(output)
        cancel!(ctx)
    end
end

"""
    serve_json(app::MaridApp; timeout_ms=30000, max_response_bytes=1048576, kwargs...)

Start the optional unary JSON server and return its closable server handle. Loading
MaridCodec and MaridTransport activates this method. The app becomes ready after
startup and becomes not ready and draining when the server shuts down.

Handlers must cooperatively return exactly one item in a closed Stream; arbitrary
CPU work cannot be forcibly cancelled. No authentication or JSON Schema validation
is inferred from IR annotations. Application services validate/authorise inputs.
Throw `ArgumentError` when either limit is not positive; remaining keyword arguments
are forwarded to `serve_http`.
"""
function serve_json(app::MaridApp; timeout_ms::Int=30000, max_response_bytes::Int=1048576, kwargs...)
    timeout_ms > 0 || throw(ArgumentError("Timeout must be positive"))
    max_response_bytes > 0 || throw(ArgumentError("Response limit must be positive"))
    server = serve_http(req -> handle_json(app, req, timeout_ms, max_response_bytes);
        on_shutdown=() -> (app.is_ready = false; app.is_draining = true), kwargs...)
    app.is_ready = true
    return server
end
end
