```@meta
CurrentModule = ExoMol
```

# ExoMol

`ExoMol.jl` provides convenience wrappers for downloading ExoMol line lists and
turning them into Julia-friendly structures.  It handles fetching datasets as
artifacts, parsing the associated definition files and reading the compressed
state and transition catalogues.

## Getting started

```julia
using ExoMol

# Retrieve the master catalogue that lists all available molecules
master = get_exomol_master()

# Load a dataset and inspect its contents
iso = load_isotopologue("CO", "12C-16O", "Li2015")
@info "Loaded $(length(iso.states)) states" first(iso.states)
@info "Loaded $(length(iso.transitions)) transitions"
```

The [`Isotopologue`](@ref) struct bundles the dataset definition, states and
transitions.  See the API reference below for detailed descriptions of the
helper functions involved in constructing it.

## Reference

```@index
```

```@autodocs
Modules = [ExoMol]
```
