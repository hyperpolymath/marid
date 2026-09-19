# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore

Core data plane and foundational runtime contracts for Marid.
Provides CallContext, domain error mapping (RFC 9457), bounded streaming seams,
and trie-based request routing.
"""
module MaridCore

using Dates
using UUIDs
using MaridIR

include("errors.jl")
include("context.jl")
include("streaming.jl")

end # module MaridCore
