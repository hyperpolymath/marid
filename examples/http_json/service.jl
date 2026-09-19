# SPDX-License-Identifier: MPL-2.0
using MaridIR

# This descriptor drives runtime bindings AND the capability artifact.
ServiceDescriptor("UnaryJSONExample", "0.1.0", TypeDescriptor[], [
    MethodDescriptor("status", "Void", "String"; route_path="/api/status", http_method="GET"),
    MethodDescriptor("echo", "String", "String"; route_path="/api/echo", http_method="POST",
        annotations=[Annotation("gateway.capability", "echo:write")]),
    MethodDescriptor("restrictedProbe", "Void", "String"; route_path="/api/restricted-probe", http_method="GET",
        annotations=[Annotation("gateway.exposure", "internal")]),
    MethodDescriptor("health", "Void", "Bool"; route_path="/healthz", http_method="GET")
])
