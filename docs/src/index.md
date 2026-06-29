```@meta
CurrentModule = ExoMol
```

# ExoMol.jl

ExoMol.jl downloads and parses molecular line lists from the
[ExoMol database](https://www.exomol.com/), which provides line lists for over
80 molecules relevant to exoplanetary and stellar atmospheres. The package
fetches data directly from the ExoMol web API, caches files in Julia's scratch
space, and returns parsed data in convenient Julia structs.

## Architecture

The package has two layers:

```
ExoMol web API
      │
      ▼
 Download layer     get_exomol_dataset · get_exomol_master · save_dataset
      │
      ▼
  Parse layer       read_state_file · read_trans_file · read_broad_file
      │
      ▼
 Isotopologue       .states · .transitions · .partition_function · .broadeners
```

[`load_isotopologue`](@ref) combines both layers: it downloads a dataset if
needed and returns a fully parsed [`Isotopologue`](@ref).

## Quick start

```julia
using ExoMol

# Download and load the recommended dataset for N₂
iso = load_isotopologue("N2", "14N2")
# Isotopologue: 14N2 / WCCRMT
#   States:              58,380
#   Transitions:         7,182,000
#   Partition function:  T ∈ [1.0, 9000.0] K
#   Broadeners:          none

# Evaluate the partition function at 1000 K
iso.partition_function(1000.0)

# Access individual states and transitions
iso.states[1]
iso.transitions[1]
```

See the [Guide](@ref) for a full walkthrough, or jump to the
[API reference](@ref "Download API").
