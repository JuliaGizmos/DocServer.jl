# DocServer

In `docs/make.jl`
1. write `using Documenter, DocServer` instead of just `using Documenter`
2. pass `assets = ["pkg/WebIO/webio.bundle.js", "pkg/DocServer/custom.js"]` option to `makedocs`
3. use `@live` blocks in docs like `@example` blocks to run code every time a page is loaded. Use [WebIO](https://github.com/JuliaGizmos/WebIO.jl) to create interactive widgets.
