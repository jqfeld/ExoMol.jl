using ExoMol
using Documenter

DocMeta.setdocmeta!(ExoMol, :DocTestSetup, :(using ExoMol); recursive=true)

makedocs(;
    modules=[ExoMol],
    authors="Jan Kuhfeld <jan.kuhfeld@rub.de> and contributors",
    sitename="ExoMol.jl",
    format=Documenter.HTML(;
        canonical="https://jqfeld.github.io/ExoMol.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home"  => "index.md",
        "Guide" => "guide.md",
        "API"   => [
            "Download"  => "api/download.md",
            "Load"      => "api/load.md",
            "Types"     => "api/types.md",
            "Low-level" => "api/parse.md",
        ],
    ],
)

deploydocs(;
    repo="github.com/jqfeld/ExoMol.jl",
    devbranch="main",
)
