# SPDX-License-Identifier: MPL-2.0
using Test
using MaridIR

@testset "Native capability spec" begin
    fixture = joinpath(@__DIR__, "../../../fixtures/capability")
    svc = include(joinpath(fixture, "service.jl"))
    emit(s; kw...) = emit_capability_spec(s; global_verbs=["GET"], kw...)
    service(methods; annotations=Annotation[]) = ServiceDescriptor("Test", "1", TypeDescriptor[], methods; annotations)
    method(path; verb="POST", annotations=Annotation[]) = MethodDescriptor("test", "Void", "String"; route_path=path, http_method=verb, annotations)
    @test emit(svc) == read(joinpath(fixture, "policy.yaml"), String)
    @test emit_capability_spec(svc; global_verbs=String[], gateway_profile=:strict) == read(joinpath(fixture, "policy-strict.yaml"), String)
    @test_throws ArgumentError emit_capability_spec(svc; global_verbs=["GET"], gateway_profile=:strict)
    @test_throws ArgumentError emit_capability_spec(svc; global_verbs=String[], gateway_profile=:unknown)
    @test emit(ServiceDescriptor(svc.name, svc.version, svc.types, reverse(svc.methods))) == emit(svc)
    @test emit_capability_spec(svc; global_verbs=["get", "GET"]) == emit(svc)
    @test_throws UndefKeywordError emit_capability_spec(svc)
    @test_throws ArgumentError emit_capability_spec(svc; global_verbs=String[])
    @test_throws ArgumentError emit_capability_spec(svc; global_verbs=["TRACE"])
    @test_throws ArgumentError emit(svc; status_code=405)
    @test occursin("enabled: false", emit(svc; stealth=false))
    @test !occursin("rpcOnly", emit(svc))
    @test !occursin("HEAD", emit(svc))
    @test !occursin("OPTIONS", emit(svc))
    @test occursin("verbs: [GET, POST]", emit(svc))
    @test occursin(raw"\A/api/entities/[^/]+\z", emit(svc))
    @test occursin(raw"\A/api/export\.v1\z", emit(svc))
    @test_throws ArgumentError emit(service(MethodDescriptor[]))
    @test_throws ArgumentError emit(service([method("/x"; verb="CONNECT")]))
    for path in ("x", "/x/", "/x//y", "/x?y", "/x#y", "/x/%2F", "/x/{id}", "/x/:9bad", "/x/:id/:id", "/x/*/y", "/x/a*", "/x\ny", "/x y", "/x\u2028y")
        @test_throws ArgumentError emit(service([method(path)]))
    end
    for path in ("/health", "/ready", "/metrics", "/api/v1/minikaran", "/:any", "/*")
        @test_throws ArgumentError emit(service([method(path)]))
    end
    for (a, b) in (("/x/:id", "/x/new"), ("/x/*", "/x/:id"), ("/x/:id", "/x/:name"))
        @test_throws ArgumentError emit(service([method(a), MethodDescriptor("other", "Void", "String"; route_path=b)]))
    end
    wildcard = MaridIR._capability_pattern(MaridIR._capability_segments("/files/*"))
    @test occursin(Regex(wildcard), "/files/a/b")
    @test !occursin(Regex(wildcard), "/files/")
    escaped = MaridIR._capability_pattern(MaridIR._capability_segments("/x/a.b+[q](r)|^\$\\"))
    @test occursin(Regex(escaped), "/x/a.b+[q](r)|^\$\\")
    @test !occursin(Regex(escaped), "/x/axbq")
    @test !occursin(Regex(escaped), "/x/a.b+[q](r)|^\$\\\n")
    ann = [Annotation("gateway.exposure", "internal"), Annotation("gateway.capability", "owner's:write")]
    annotated = emit(service([method("/x"; annotations=ann)]))
    @test occursin("exposure: 'internal'", annotated)
    @test occursin("capability: 'owner''s:write'", annotated)
    @test occursin("exposure: 'internal'", emit(service([method("/x")]; annotations=ann)))
    @test occursin("exposure: 'public'", emit(service([method("/x"; annotations=[Annotation("gateway.exposure", "public")])]; annotations=ann)))
    for annotations in ([Annotation("gateway.unknown", "x")], [Annotation("gateway.exposure", "admin")], [Annotation("gateway.capability", " ")], [Annotation("gateway.capability", "x\ny")], [ann[1], ann[1]])
        @test_throws ArgumentError emit(service([method("/x"; annotations)]))
    end
    @test_throws ArgumentError emit(service([method("/x"; annotations=ann), MethodDescriptor("other", "Void", "String"; route_path="/x", http_method="GET")]))
    @test_throws ErrorException emit(service([method("/x"), method("/x")]))
end
