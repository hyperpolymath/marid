# SPDX-License-Identifier: MPL-2.0
# Instantiate an independent project and its transitive local Marid dependencies.
using Pkg, TOML
length(ARGS) == 1 || error("Usage: julia scripts/bootstrap.jl <project-directory>")
root = dirname(@__DIR__)
environment = abspath(ARGS[1])
projects = Dict{String,String}()
for directory in readdir(joinpath(root, "packages"); join=true)
    file = joinpath(directory, "Project.toml")
    isfile(file) || continue
    projects[TOML.parsefile(file)["name"]] = directory
end
selected = Set{String}()
function visit(directory)
    config = TOML.parsefile(joinpath(directory, "Project.toml"))
    for name in keys(get(config, "deps", Dict()))
        if haskey(projects, name) && !(name in selected)
            push!(selected, name)
            visit(projects[name])
        end
    end
end
visit(environment)
cd(environment) do
    Pkg.activate(".")
    specs = [Pkg.PackageSpec(path=relpath(projects[name], environment)) for name in sort!(collect(selected))]
    isempty(specs) || Pkg.develop(specs)
    Pkg.resolve()
    Pkg.instantiate()
end
