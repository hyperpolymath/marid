# SPDX-License-Identifier: MPL-2.0
using MaridIR

# Shared-path methods deliberately use the same governance metadata.
ServiceDescriptor("CapabilityExample", "1.0.0", TypeDescriptor[], [
    MethodDescriptor("listEntities", "Void", "String";
        route_path="/api/entities", http_method="GET"),
    MethodDescriptor("createEntity", "String", "String";
        route_path="/api/entities", http_method="POST"),
    MethodDescriptor("getEntity", "String", "String";
        route_path="/api/entities/:id", http_method="GET"),
    MethodDescriptor("exportEntity", "String", "Bytes";
        route_path="/api/export.v1", http_method="POST",
        annotations=[Annotation("gateway.capability", "entities:export")]),
    MethodDescriptor("rpcOnly", "String", "String")
])
