```@meta
CurrentModule = ExoMol
```

# Load API

[`load_isotopologue`](@ref) is the main entry point for getting data into Julia.
It has three methods that share the same keyword arguments:

| Form | Description |
|------|-------------|
| `load_isotopologue(folder)` | Load from a local directory |
| `load_isotopologue(molecule, isotopologue, dataset)` | Download + load a named dataset |
| `load_isotopologue(molecule, isotopologue)` | Download + load the recommended dataset |

All three return an [`Isotopologue`](@ref).

```@docs
load_isotopologue(folder::AbstractString)
load_isotopologue(molecule, isotopologue, dataset)
load_isotopologue(molecule, isotopologue)
read_pf_file
```
