# SPDX-License-Identifier: MPL-2.0
using Test, HTTP, JSON3, Sockets
include("../app.jl")

@testset "Real HTTP/JSON socket integration" begin
    app, writes = build_example()
    server = serve_json(app; port=0, max_body_bytes=128, readtimeout=2)
    url = "http://127.0.0.1:$(listening_port(server))"
    request(method, path; headers=Pair{String,String}[], body="") =
        HTTP.request(method, url * path, headers, body; status_exception=false, retry=false)
    try
        @test app.is_ready
        r = request("POST", "/api/echo"; headers=["Content-Type"=>"application/json"], body=JSON3.write("quotes \" unicode λ\n"))
        @test r.status == 200
        @test JSON3.read(r.body) == "quotes \" unicode λ\n"
        @test writes[] == 1
        @test HTTP.header(r, "Vary") == "Accept"
        @test HTTP.header(r, "Content-Type") == "application/json"
        @test !isempty(HTTP.header(r, "X-Request-ID"))
        @test request("GET", "/api/status?query=ok").status == 200
        @test JSON3.read(request("GET", "/healthz").body) === true
        @test request("GET", "/absent").status == 404
        @test request("GET", "/api/echo").status == 405
        @test HTTP.header(request("DELETE", "/api/echo"), "Allow") == "POST"
        @test request("HEAD", "/api/echo").status == 405
        @test request("OPTIONS", "/api/echo").status == 405
        @test request("POST", "/api/echo"; headers=["Content-Type"=>"text/plain"], body="x").status == 415
        @test request("POST", "/api/echo"; headers=["Content-Type"=>"application/json"], body="{").status == 400
        @test request("POST", "/api/echo"; headers=["Content-Type"=>"application/json"], body="42").status == 400
        @test request("GET", "/api/status"; headers=["Accept"=>"text/html"]).status == 406
        @test request("GET", "/api/status"; headers=["Accept"=>"application/json;q=0, */*;q=1"]).status == 406
        @test request("POST", "/api/echo"; headers=["Content-Type"=>"application/json"], body="x"^129).status == 413
        for path in ["/api//echo", "/api/echo/", "/api/%65cho"]
            @test request("POST", path).status == 400
        end
        socket = connect(ip"127.0.0.1", listening_port(server))
        try
            write(socket, "POST /api/echo HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n81\r\n" * "x"^129 * "\r\n0\r\n\r\n")
            flush(socket)
            @test occursin(" 413 ", readline(socket))
        finally
            close(socket)
        end
        @test writes[] == 1 # invalid requests never invoke the mutation handler
        # Independently implemented HTTP client, not a direct Julia dispatcher call.
        curl = read(`curl --fail --silent --show-error $url/healthz`, String)
        @test curl == "true"
        app.is_draining = true
        @test request("GET", "/healthz").status == 503
        app.is_draining = false
    finally
        close(server)
        app.is_ready = false
    end
    @test !isopen(server)
    @test !app.is_ready
    @test app.is_draining
end

@testset "Redaction, cooperative deadline, schema binding and routing" begin
    app = MaridApp()
    svc = ServiceDescriptor("FailureCases", "1", TypeDescriptor[], [
        MethodDescriptor("failure", "Void", "String"; route_path="/fail", http_method="GET"),
        MethodDescriptor("slow", "Void", "String"; route_path="/slow", http_method="GET"),
        MethodDescriptor("root", "Void", "String"; route_path="/", http_method="GET"),
        MethodDescriptor("nested", "Void", "String"; route_path="/a/:first/b/:second", http_method="GET")])
    handlers = Dict{String,Function}(
        "failure" => (ctx, call) -> error("private credential value"),
        "slow" => (ctx, call) -> (sleep(0.03); unary_result(ctx, "too late")),
        "root" => (ctx, call) -> unary_result(ctx, "root"),
        "nested" => (ctx, call) -> unary_result(ctx, call.params["first"] * call.params["second"]))
    @test_throws ArgumentError bind_service!(app, svc, Dict())
    @test isempty(app.routes.roots) # failed bind made no partial registration
    bind_service!(app, svc, handlers)
    server = serve_json(app; port=0, timeout_ms=10)
    url = "http://127.0.0.1:$(listening_port(server))"
    try
        r = HTTP.get(url * "/fail"; status_exception=false, retry=false)
        @test r.status == 500
        @test !occursin("credential", String(copy(r.body)))
        @test JSON3.read(r.body).status == 500
        @test HTTP.get(url * "/slow"; status_exception=false, retry=false).status == 504
        @test JSON3.read(HTTP.get(url * "/").body) == "root"
        @test JSON3.read(HTTP.get(url * "/a/one/b/two").body) == "onetwo"
    finally
        close(server)
    end
end
