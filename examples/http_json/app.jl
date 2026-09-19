# SPDX-License-Identifier: MPL-2.0
using MaridIR, MaridCore, MaridCodec, MaridTransport

function unary_result(ctx, value)
    output = Stream{Any}(1, ctx)
    push_item!(output, value)
    close_stream!(output)
    return output
end

function build_example()
    descriptor = include(joinpath(@__DIR__, "service.jl"))
    app = MaridApp()
    writes = Threads.Atomic{Int}(0)
    handlers = Dict{String,Function}(
        "status" => (ctx, call) -> unary_result(ctx, "echo writes: $(writes[])"),
        # Synthetic probe only, not authenticated application data.
        "restrictedProbe" => (ctx, call) -> unary_result(ctx, "test-only restricted probe"),
        "health" => (ctx, call) -> unary_result(ctx, true),
        "echo" => (ctx, call) -> begin
            input = only(collect_stream(call.input))
            input isa AbstractString || throw(ValidationError("Expected a JSON string", "body", "type"))
            Threads.atomic_add!(writes, 1)
            unary_result(ctx, String(input))
        end
    )
    bind_service!(app, descriptor, handlers)
    return app, writes
end
