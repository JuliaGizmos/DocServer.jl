module DocServer

import Documenter
import Documenter: Selectors, Utilities, Documents, Expanders
import Documenter.Expanders: ExpanderPipeline
import Documenter.Builder: DocumentPipeline

using Mux
using WebIO

"""
"""
abstract type LiveBlocks <: ExpanderPipeline end
Selectors.order(::Type{LiveBlocks})     = 8.5
Selectors.matcher(::Type{LiveBlocks},  node, page, doc) = Expanders.iscode(node, r"^@live")

const live_blocks = Dict{String, Any}()

function Selectors.runner(::Type{LiveBlocks}, x, page, doc)
    matched = match(r"^@live[ ]?(.*)$", x.language)
    matched === nothing && error("invalid '@live' syntax: $(x.language)")
    # The sandboxed module -- either a new one or a cached one from this page.

    key = page.source
    name = matched[1]
    sym  = isempty(name) ? gensym("live-") : Symbol("live-", name)
    mod  = get!(page.globals.meta, sym, Module(sym))::Module
    content = []
    input   = Expanders.droplines(x.code)

    if !haskey(live_blocks, key)
        live_blocks[key] = []
    end
    push!(live_blocks[key], (page, doc, mod, input))

    id = "$key/live-$(length(live_blocks[key]))"
    scr = """
    <script>alert("liveblock $id")</script>
    """
    output = Documents.RawHTML(scr)

    # Only add content when there's actually something to add.
    isempty(input)  || push!(content, Markdown.Code("julia", input))
    isempty(output.code) || push!(content, output)
    # ... and finally map the original code block to the newly generated ones.
    page.mapping[x] = Markdown.MD(content)
end

"""
Adds the document to the Mux app
"""
abstract type ServeDocument <: DocumentPipeline end
Selectors.order(::Type{ServeDocument}) = typemax(Float64) - π

"""
Adds the document to the Mux app
"""
abstract type InsertWebIO <: DocumentPipeline end
Selectors.order(::Type{InsertWebIO}) = 2.5

function Selectors.runner(::Type{InsertWebIO}, doc::Documents.Document)
   #for (src, p) in doc.internal.pages
   #    key = p.source
   #    #s = Markdown.MD([Documents.RawHTML("<script>alert('init $key')</script>")])
   #    #p.mapping[s] = s
   #    #unshift!(p.elements, s)
   #    @show p.elements
   #    s = Markdown.MD([Documents.RawHTML("<script>alert('fin $key')</script>")])
   #    push!(p.elements, s)
   #    p.mapping[s] = s
   #end
end

function server(req)
    @show req
    key = req.params[:key]
    @show key
    if haskey(liveblocks, key)
        "yes!"
    end
end

include(Pkg.dir("WebIO", "src", "providers", "mux_setup.jl"))
function Selectors.runner(::Type{ServeDocument}, doc::Documents.Document)
    Utilities.log(doc, "serving files...")
    dir = joinpath(doc.user.root, doc.user.build)
    fileserver = Mux.stack(Mux.files(dir, false),
                           branch(req -> Mux.validpath(dir, joinpath(req[:path]..., "index.html")),
                                  req -> Mux.fresp(joinpath(dir, req[:path]..., "index.html"))))
    cd(dir) do
        ware = route("", fileserver, Mux.notfound())
        webio_serve(Mux.stack(page("/liveblocks/:key", server), ware))
    end
end

end # module
