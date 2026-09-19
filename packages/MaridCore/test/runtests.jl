# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridCore

@testset "MaridCore Contracts" begin
    # 1. Error Mapping & Problem Details
    @testset "RFC 9457 Domain Errors" begin
        not_found = NotFoundError("Taxon", "42")
        @test status_code(not_found) == 404
        pd = problem_details(not_found, instance="/taxa/42")
        @test pd["status"] == 404
        @test occursin("42", pd["detail"])
        @test pd["instance"] == "/taxa/42"
        
        val_err = ValidationError("Field missing", "email", "required")
        @test status_code(val_err) == 400
        
        conflict = ConflictError("Document conflict", "entities/1", "rev-abc")
        @test status_code(conflict) == 409
        
        timeout = TimeoutError("Deadline reached", 150.0)
        @test status_code(timeout) == 504
    end

    # 2. CallContext Lifecycle & Cancellation
    @testset "CallContext Semantics" begin
        ctx = create_context(principal="user:dr_smith", tenant="biology_dept", timeout_ms=500)
        @test ctx.principal == "user:dr_smith"
        @test ctx.tenant_scope == "biology_dept"
        @test !is_cancelled(ctx)
        @test !is_expired(ctx)
        @test check_deadline(ctx) > 0.0
        
        # Test explicit cancellation
        cancel!(ctx)
        @test is_cancelled(ctx) == true
        
        # Test expiration
        expired_ctx = create_context(timeout_ms=-10)
        @test is_expired(expired_ctx) == true
        @test_throws TimeoutError check_deadline(expired_ctx)
    end

    # 3. Bounded Streaming Seam & Backpressure
    @testset "Streaming Flow Control" begin
        ctx = create_context(timeout_ms=5000)
        stream = Stream{Int}(4, ctx)
        
        # Produce items asynchronously
        @async begin
            for i in 1:5
                push_item!(stream, i)
            end
            close_stream!(stream)
        end
        
        # Consume items
        items = collect_stream(stream)
        @test items == [1, 2, 3, 4, 5]
        @test is_closed(stream) == true
    end

    # 4. Stream Cancellation Interruption
    @testset "Stream Cancellation Defense" begin
        ctx = create_context(timeout_ms=5000)
        stream = Stream{String}(2, ctx)
        
        push_item!(stream, "item1")
        cancel!(ctx)
        
        # Pushing to cancelled context triggers error
        @test_throws ErrorException push_item!(stream, "item2")
    end
end
