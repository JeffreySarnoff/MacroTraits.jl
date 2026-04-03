using Documenter
using MacroTraits

DocMeta.setdocmeta!(MacroTraits, :DocTestSetup, :(using MacroTraits); recursive=true)

makedocs(
    modules=[MacroTraits],
    sitename="MacroTraits.jl",
    format=Documenter.HTML(prettyurls=get(ENV, "CI", "false") == "true"),
    doctest=false,
    pages=[
        "Home" => "index.md",
        "Examples" => "examples.md",
        "Internals" => "internals.md",
    ],
)

deploydocs(
    repo="github.com/JeffreySarnoff/MacroTraits.jl.git",
    devbranch="main",
)
