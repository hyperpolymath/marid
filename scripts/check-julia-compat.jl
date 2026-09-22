#!/usr/bin/env julia
# SPDX-License-Identifier: MPL-2.0
#
# check-julia-compat.jl — assert that every dep AND weakdep of every package
# under packages/ carries an upper-bounded [compat] entry, stdlibs included,
# and that each package's `julia` entry is bounded, below 2.0 and admits 1.x.
#
# Acceptance criterion: metadatastician/marid#22 (D68).
#
# ⚠ THIS GATE IS DELIBERATELY STRICTER THAN JULIA GENERAL AUTOMERGE.
# RegistryCI.jl sets `_AUTOMERGE_REQUIRE_STDLIB_COMPAT = false`
# (AutoMerge/src/guidelines.jl), so AutoMerge skips stdlib and JLL deps today —
# but that constant carries a TODO to flip it, and bounding stdlibs is ordinary
# good Julia practice regardless. Do NOT "fix" this control to match AutoMerge;
# the stricter rule is the specification, not an accident.
#
# Interim: D67-A will wire the real RegistryCI guideline. Until then this is a
# local stand-in that asks the registry's own question using the registry's own
# predicate.

import Pkg
import TOML

# ── The predicate, lifted VERBATIM from RegistryCI.jl AutoMerge/src/semver.jl ──
# Copied rather than paraphrased so this gate cannot drift from what the
# registry actually checks.
function _has_upper_bound(r::Pkg.Types.VersionRange)
    a = r.upper != Pkg.Types.VersionBound("*")
    b = r.upper != Pkg.Types.VersionBound("0")
    c = !(Base.VersionNumber(0, typemax(Base.VInt), typemax(Base.VInt)) in r)
    d = !(
        Base.VersionNumber(
            typemax(Base.VInt), typemax(Base.VInt), typemax(Base.VInt)
        ) in r
    )
    e = !(typemax(Base.VersionNumber) in r)
    return a && b && c && d && e
end

# `_has_upper_bound` consumes a `VersionRange`, which CANNOT parse Project.toml
# compat syntax — `Pkg.Types.VersionRange(">=0.1")` throws ArgumentError.
# `semver_spec` is the bridge: it parses the Project.toml dialect and yields
# `.ranges`. It THROWS on "*", so an unparseable or wildcard entry is reported
# as a detected defect rather than crashing the gate.
function _spec(value)
    s = value isa AbstractVector ? join(String.(value), ", ") : String(value)
    return Pkg.Types.semver_spec(s)
end

function is_upper_bounded(value)::Bool
    try
        ranges = _spec(value).ranges
        return !isempty(ranges) && all(_has_upper_bound, ranges)
    catch
        return false   # "*", ">= 0.1" with bad syntax, malformed — all defects
    end
end

# Mirrors RegistryCI's `guideline_compat_for_julia`: bounded, upper bound below
# 2, and the range must actually admit some 1.x.
function julia_compat_ok(value)::Bool
    try
        spec = _spec(value)
        isempty(spec.ranges) && return false
        all(_has_upper_bound, spec.ranges) || return false
        isempty(intersect(spec, Pkg.Types.VersionSpec("2-*"))) || return false
        isempty(intersect(spec, Pkg.Types.VersionSpec("1"))) && return false
        return true
    catch
        return false
    end
end

"Return a list of human-readable defects for one parsed Project.toml."
function defects(proj::AbstractDict)
    out = String[]
    compat = get(proj, "compat", Dict{String,Any}())
    deps = get(proj, "deps", Dict{String,Any}())
    weakdeps = get(proj, "weakdeps", Dict{String,Any}())
    required = sort(collect(union(keys(deps), keys(weakdeps))))

    for name in required
        kind = haskey(deps, name) ? "dep" : "weakdep"
        if !haskey(compat, name)
            push!(out, "$kind `$name` has no [compat] entry")
        elseif !is_upper_bounded(compat[name])
            push!(out, "$kind `$name = $(repr(compat[name]))` has no upper bound")
        end
    end

    if !haskey(compat, "julia")
        push!(out, "no [compat] entry for `julia`")
    elseif !julia_compat_ok(compat["julia"])
        push!(
            out,
            "`julia = $(repr(compat["julia"]))` is unbounded, admits 2.x, or excludes 1.x",
        )
    end
    return out
end

# ── Self-test ────────────────────────────────────────────────────────────────
# A passing check proves nothing until a mutant dies. Each fixture seeds one
# defect class; the clean control guards against a gate that reports everything
# as broken. Exit 2 if any seeded defect goes undetected.
const FIXTURES = [
    ("missing dep entry",
     Dict("deps" => Dict("Dates" => "u"), "compat" => Dict("julia" => "1.10")), true),
    ("unbounded >=",
     Dict("deps" => Dict("Dates" => "u"),
          "compat" => Dict("Dates" => ">=0.1", "julia" => "1.10")), true),
    ("wildcard *",
     Dict("deps" => Dict("Dates" => "u"),
          "compat" => Dict("Dates" => "*", "julia" => "1.10")), true),
    ("missing weakdep entry",
     Dict("deps" => Dict{String,Any}(), "weakdeps" => Dict("MaridCodec" => "u"),
          "compat" => Dict("julia" => "1.10")), true),
    ("no julia entry",
     Dict("deps" => Dict("Dates" => "u"), "compat" => Dict("Dates" => "1")), true),
    ("julia admits 2.x",
     Dict("deps" => Dict{String,Any}(), "compat" => Dict("julia" => "1.10, 2")), true),
    ("CLEAN control",
     Dict("deps" => Dict("Dates" => "u"), "weakdeps" => Dict("MaridCodec" => "u"),
          "compat" => Dict("Dates" => "1", "MaridCodec" => "0.1",
                           "julia" => "1.10")), false),
]

function self_test()::Bool
    ok = true
    for (name, proj, should_fail) in FIXTURES
        got = !isempty(defects(proj))
        if got != should_fail
            verb = should_fail ? "MISSED seeded defect" : "FALSE POSITIVE on"
            println("  self-test: $verb: $name")
            ok = false
        end
    end
    println(ok ? "  self-test: $(length(FIXTURES))/$(length(FIXTURES)) OK" :
                 "  self-test: FAILED")
    return ok
end

# ── Main ─────────────────────────────────────────────────────────────────────
function main()
    root = dirname(@__DIR__)
    pkgdir = joinpath(root, "packages")

    println("check-julia-compat: deps+weakdeps must carry upper-bounded [compat]")
    self_test() || (println("ABORT: the gate cannot detect its own fixtures."); exit(2))

    isdir(pkgdir) || (println("ABORT: no packages/ directory at $pkgdir"); exit(2))

    checked = 0
    failed = String[]
    for name in sort(readdir(pkgdir))
        path = joinpath(pkgdir, name, "Project.toml")
        isfile(path) || continue
        checked += 1
        proj = try
            TOML.parsefile(path)
        catch e
            push!(failed, name)
            println("FAIL $name: unparseable Project.toml ($(typeof(e)))")
            continue
        end
        ds = defects(proj)
        if isempty(ds)
            println("ok   $name")
        else
            push!(failed, name)
            println("FAIL $name")
            for d in ds
                println("       - $d")
            end
        end
    end

    # A gate that finds nothing to check has failed, not passed.
    if checked == 0
        println("ABORT: found no packages/*/Project.toml to check.")
        exit(2)
    end

    println("\nchecked $checked package(s); $(length(failed)) failing")
    if !isempty(failed)
        println("failing: $(join(failed, ", "))")
        exit(1)
    end
    println("All packages carry upper-bounded [compat] for every dep and weakdep.")
    return nothing
end

main()
