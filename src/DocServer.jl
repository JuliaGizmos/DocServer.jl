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

    key = replace(page.source, "/", ":")
    name = matched[1]
    sym  = isempty(name) ? gensym("live-") : Symbol("live-", name)
    mod  = get!(page.globals.meta, sym, Module(sym))::Module
    content = []
    input   = Expanders.droplines(x.code)

    if !haskey(live_blocks, key)
        live_blocks[key] = []
    end
    push!(live_blocks[key], (page, doc, mod, input))

    id = "live-$(length(live_blocks[key]))"
    scr = """
    <div id="$id">live output $id</div>
    <script>loadliveblocks($(JSON.json(key)))</script>
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

function htmlrender(m::Union{MIME"text/html",
                            MIME"text/plain",
                            MIME"text/svg"}, x)
    stringmime(m, x)
end

function htmlrender(m::Union{MIME"image/png", MIME"image/jpeg"})
    "<img src=\"data:image/png;base64,$(stringmime(m, img))\">"
end

const bestmimes = MIME.(["text/html", "text/svg", "image/png", "image/jpeg"])

function htmlrender(x)
    for m in bestmimes
        if mimewritable(m, x)
            return htmlrender(m, x)
       end
    end
    return string(x)
end

function server(req)
    key = req[:params][:key]
    @show keys(live_blocks) |> collect
    if haskey(live_blocks, key)
        blocks = []
        for (page, doc, mod, input) in live_blocks[key]
            result = nothing
            for (ex, str) in Utilities.parseblock(input, doc, page)
                (value, success, backtrace, text) = Utilities.withoutput() do
                    cd(dirname(page.build)) do
                        eval(mod, ex)
                    end
                end
                result = value
                if !success
                    Utilities.warn(page.source, "failed to run code block.\n\n$(value)")
                    return
                end
            end
            push!(blocks, htmlrender(result))
        end

        return Dict(
                    :headers => Dict("Content-Type" => "text/json"),
                    :body => JSON.json(blocks)
                   )
    end
    return Dict(
                :headers => Dict("Content-Type"=> "text/json"),
                :body => ""
               )
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
