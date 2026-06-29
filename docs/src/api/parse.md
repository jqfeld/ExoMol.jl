```@meta
CurrentModule = ExoMol
```

# Low-level parse API

These functions are the building blocks that [`load_isotopologue`](@ref) calls
internally. They are exported for users who need fine-grained control — for
example, reading a single states file without loading transitions, or building
a custom loading pipeline.

## Definition file

```@docs
read_def_file
```

## States file

```@docs
read_state_file
```

## Transitions file

```@docs
read_trans_file
```

## Broadening file

```@docs
read_broad_file
```
