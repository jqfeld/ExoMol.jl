```@meta
CurrentModule = ExoMol
```

# ExoMol

`ExoMol.jl` provides lightweight tooling for downloading, parsing, and
working with spectroscopic datasets from the
[ExoMol project](https://www.exomol.com/).  The package wraps the ExoMol
distribution format in a set of convenient Julia functions and types so
that you can focus on analysing the data.

## Getting started

```julia
julia> using ExoMol

julia> master = get_exomol_master();

julia> dataset_dir = get_exomol_dataset("H2O", "1H2-16O", "POKAZATEL");

julia> iso = load_isotopologue(dataset_dir)
Isotopologue{NamedTuple} with 3 fields
```

The [`Isotopologue`](@ref) object bundles the dataset definition, state
records, and transition data into a single, ready-to-use structure.

## Master catalogue

Use the master catalogue to inspect the molecules and datasets that are
available from the ExoMol project.

```@docs
ExoMol.get_exomol_master
ExoMol.get_exomol_master_file
ExoMol.parse_exomol_master
```

## Working with datasets

After identifying the dataset of interest, download it as an artifact
and construct an [`Isotopologue`](@ref) for convenient access to the
parsed records.

```@docs
ExoMol.get_exomol_dataset
ExoMol.read_def_file
ExoMol.read_state_file
ExoMol.read_trans_file
ExoMol.load_isotopologue
```

```@index
```

```@autodocs
Modules = [ExoMol]
```
