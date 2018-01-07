using Documenter, DocServer

makedocs(
         debug=true,
   modules = [Base.Iterators],
   clean = false,
   format = [:html],#, :latex],
   sitename = "DocServer Test",
   pages = Any[
       "Home" => "sample.md",
   ],
   assets = ["pkg/WebIO/webio.bundle.js", "pkg/DocServer/custom.js"]
)

#=
deploydocs(
    repo = "github.com/JuliaGizmos/DocServer.jl.git",
    target = "build",
    julia = "0.6",
    osname = "linux",
    deps = nothing,
    make = nothing,
)
=#
