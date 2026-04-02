using Documenter
using MacroTraits

DocMeta.setdocmeta!(MacroTraits, :DocTestSetup, :(using MacroTraits); recursive = true)

makedocs(
    modules = [MacroTraits],
    sitename = "MacroTraits.jl",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", "false") == "true"),
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/JeffreySarnoff/MacroTraits.jl.git",
    devbranch = "main",
)
