```@meta
CurrentModule = ExoMol
```

# [Guide](@id Guide)

This guide walks through the full workflow from discovering molecules in the
ExoMol catalogue to working with the loaded data in Julia.

## Installation

```julia
import Pkg
Pkg.add("ExoMol")
```

## Discovering available molecules

The ExoMol master catalogue lists every molecule, isotopologue, and dataset
available in the database. Fetch it with [`get_exomol_master`](@ref):

```julia
using ExoMol

master = get_exomol_master()
master["num_molecules"]   # total number of molecules
master["num_datasets"]    # total number of datasets
keys(master["molecules"]) # molecule names
```

The catalogue is cached in Julia's scratch space after the first download. Pass
`force=true` to re-download.

## Loading a dataset

The simplest entry point is [`load_isotopologue`](@ref), which downloads (if
needed) and parses a dataset in one call.

### Auto-select the recommended dataset

```julia
iso = load_isotopologue("N2", "14N2")
```

The ExoMol API marks one dataset per isotopologue as recommended. This form
selects it automatically and prints an `@info` message naming it.

### Specify the dataset explicitly

```julia
iso = load_isotopologue("N2", "14N2", "WCCRMT")
```

Use this form when you need a specific dataset rather than the recommended one.

### Load from a local directory

If you have already downloaded files (via [`save_dataset`](@ref) or manually),
pass the folder path directly:

```julia
iso = load_isotopologue("/data/exomol/N2/14N2/WCCRMT")
```

## Filtering by wavenumber

Large datasets (e.g. H₂O POKAZATEL has 412 transition files totalling ~200 GB
uncompressed) can be restricted to a wavenumber window using `wn_range`:

```julia
# Download and load only transitions between 1000 and 4000 cm⁻¹
iso = load_isotopologue("H2O", "1H2-16O", "POKAZATEL"; wn_range=(1000, 4000))
```

`wn_range` uses an **overlap** criterion: a transition file is included if its
wavenumber range overlaps `[wn_min, wn_max]`. Unsegmented transition files
(those without an explicit range in their filename) are always included.

The same `wn_range` keyword works when loading from a local folder:

```julia
iso = load_isotopologue("/data/exomol/H2O/1H2-16O/POKAZATEL"; wn_range=(1000, 4000))
```

## Downloading to a user directory

By default ExoMol files land in Julia's scratch space, which means a separate
copy on disk if you also want the files in a specific location. Pass `dest` to
download directly into the directory of your choice:

```julia
iso = load_isotopologue("N2", "14N2", "WCCRMT"; dest="/data/exomol/N2")
```

Files are written straight into `dest` (created if it does not exist) with no
additional sub-directories appended. The same path is returned by
[`get_exomol_dataset`](@ref) and can be loaded separately:

```julia
dir = get_exomol_dataset("N2", "14N2", "WCCRMT"; dest="/data/exomol/N2")
iso = load_isotopologue(dir)
```

`dest` combines naturally with `wn_range`:

```julia
iso = load_isotopologue("H2O", "1H2-16O", "POKAZATEL";
                        dest="/data/exomol/H2O", wn_range=(1000, 4000))
```

## Copying a cached dataset

If the dataset is already in the scratch space and you want to archive or share
it, [`save_dataset`](@ref) copies it to a directory you control:

```julia
save_dataset("/data/exomol", "N2", "14N2", "WCCRMT")
# Then load from the saved path:
iso = load_isotopologue("/data/exomol")
```

If the dataset was downloaded with a `wn_range` filter, only the downloaded
transition files are copied.

## Working with the result

[`load_isotopologue`](@ref) returns an [`Isotopologue`](@ref) struct with five
fields.

### States

`iso.states` is a `Vector` of `NamedTuple`s whose field names and types are
inferred from the dataset definition. The exact fields vary by molecule:

```julia
iso.states[1]           # first state record
iso.states[1].E         # energy in cm⁻¹
iso.states[1].J         # rotational quantum number
length(iso.states)      # total number of states
```

Integer fields that are not applicable for a given state (marked `nan` in the
ExoMol file) are stored as the sentinel value `-2`.

### Transitions

`iso.transitions` is a `Vector{Transition}`. Each `Transition` holds:
- `upper_id`, `lower_id` — state identifiers matching `iso.states[i].ID`
- `A` — Einstein A coefficient (s⁻¹)
- `wavenumber` — transition wavenumber (cm⁻¹)

```julia
iso.transitions[1]
# Transition(6853 → 27271, A=8.0613e-26 s⁻¹, ν̃=0.000147 cm⁻¹)

iso.transitions[1].A           # Einstein A coefficient
iso.transitions[1].wavenumber  # wavenumber in cm⁻¹
```

Transition files are read in parallel (one task per file) using
`Threads.@spawn`.

### Partition function

`iso.partition_function` is a `DataInterpolations.LinearInterpolation` of Q(T)
over temperature, or `nothing` if no `.pf` file was found:

```julia
isnothing(iso.partition_function) || iso.partition_function(296.0)  # Q at 296 K
```

### Broadeners

`iso.broadeners` is a `Dict{String, Vector{BroadeningLine}}` keyed by broadener
name (e.g. `"H2"`, `"He"`). It is empty for datasets without broadening files.

```julia
haskey(iso.broadeners, "H2") && iso.broadeners["H2"][1]
# BroadeningLine("a1", γ_L=0.0916, n=0.790, q1=0.0, q2=1.0)
```

Each [`BroadeningLine`](@ref) holds a recipe code, Lorentzian HWHM coefficient
(`gamma_L`), temperature exponent (`n_air`), and up to two quantum numbers
(`q1`, `q2`) used for recipe lookup.

### Definitions

`iso.definitions` is the raw parsed `.def.json` dict, useful for inspecting
dataset metadata:

```julia
iso.definitions["dataset"]["name"]
iso.definitions["dataset"]["max_temperature"]
iso.definitions["isotopologue"]["iso_slug"]
```

## Broadening fallback

Some isotopologues lack broadening files. If you need broadening data and
another isotopologue of the same molecule has it cached locally, use
`broad_fallback=true`:

```julia
iso = load_isotopologue("N2", "14N2"; broad_fallback=true)
```

To borrow from a specific isotopologue rather than auto-detecting one:

```julia
iso = load_isotopologue("H2O", "1H2-18O"; broad_fallback="1H2-16O")
```

If no suitable cached broadening data is found, a warning is issued and the
returned `Isotopologue` has an empty `broadeners` dict.
