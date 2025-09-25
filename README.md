# ExoMol

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jqfeld.github.io/ExoMol.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jqfeld.github.io/ExoMol.jl/dev/)
[![Build Status](https://github.com/jqfeld/ExoMol.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jqfeld/ExoMol.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jqfeld/ExoMol.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jqfeld/ExoMol.jl)

Utilities for downloading and parsing [ExoMol](https://www.exomol.com/) line
lists directly from Julia. The package wraps the official catalogue,
transitions and state files in convenient Julia types for further analysis or
visualisation.

## Installation

Install the package from the Julia package manager:

```julia-repl
julia> import Pkg
julia> Pkg.add("ExoMol")
```

## Quick start

Fetch the ExoMol master catalogue and load a specific isotopologue dataset:

```julia
using ExoMol

# Inspect the ExoMol master catalogue
master = get_exomol_master()
println("There are $(length(master["molecules"])) molecules available.")

# Download and load a molecule/isotopologue/dataset triple
iso = load_isotopologue("H2O", "1H2-16O", "POKAZATEL")

println("Loaded $(length(iso.states)) states and $(length(iso.transitions)) transitions")
```

See the [documentation](https://jqfeld.github.io/ExoMol.jl/dev/) for a complete
API reference and additional usage examples.
