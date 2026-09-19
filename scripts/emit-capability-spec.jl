# SPDX-License-Identifier: MPL-2.0
# Called by scripts/marid; ARGS are data, never interpolated into Julia source.
using MaridIR

try
    length(ARGS) == 3 || error("Expected service file, global verbs and gateway profile")
    profile = ARGS[3] == "strict" ? :strict : ARGS[3] == "legacy" ? :legacy : error("Unknown gateway profile")
    path = abspath(ARGS[1])
    isfile(path) || error("Service file not found: $path")
    verbs = profile == :strict ? String[] : String.(split(ARGS[2], ','; keepempty=true))
    # A descriptor file is trusted executable Julia, not a data-only document.
    # Keep accidental descriptor diagnostics off machine-readable stdout.
    service = redirect_stdout(stderr) do
        Base.include(Module(:MaridCapabilityInput), path)
    end
    service isa ServiceDescriptor || error("Service file must return a MaridIR.ServiceDescriptor as its final expression")
    spec = emit_capability_spec(service; global_verbs=verbs, gateway_profile=profile)
    if profile == :legacy
        println(stderr, "Warning: public global fallback is enabled; this is not a deny-by-default policy.")
    else
        println(stderr, "Strict deny-default spec: requires the paired gateway validator/compiler fix.")
    end
    print(spec)
catch exception
    print(stderr, "marid: ")
    showerror(stderr, exception)
    println(stderr)
    exit(1)
end
