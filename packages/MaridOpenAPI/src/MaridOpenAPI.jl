# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridOpenAPI

OpenAPI 3.1 and JSON Schema 2020-12 generator emitted directly from `MaridIR.ServiceDescriptor`.
"""
module MaridOpenAPI

using MaridIR

export emit_openapi_json

"""
    emit_openapi_json(svc::ServiceDescriptor) -> String

Emits an OpenAPI 3.1 specification JSON from a service descriptor.
"""
function emit_openapi_json(svc::ServiceDescriptor)::String
    paths_list = String[]
    for m in svc.methods
        p = isempty(m.route_path) ? "/$(m.name)" : m.route_path
        verb = lowercase(m.http_method)
        push!(paths_list, """    "$p": {
      "$verb": {
        "operationId": "$(m.name)",
        "summary": "$(m.description)",
        "responses": {
          "200": {
            "description": "Successful operation"
          }
        }
      }
    }""")
    end
    paths_str = join(paths_list, ",\n")
    
    return """{
  "openapi": "3.1.0",
  "info": {
    "title": "$(svc.name)",
    "version": "$(svc.version)",
    "description": "$(svc.description)"
  },
  "paths": {
$paths_str
  }
}"""
end

end # module MaridOpenAPI
