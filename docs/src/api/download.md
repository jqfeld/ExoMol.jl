```@meta
CurrentModule = ExoMol
```

# Download API

These functions handle fetching data from the ExoMol web API. By default files
are cached in Julia's scratch space (`~/.julia/scratchspaces/`) and persist
across Julia sessions; files are only re-downloaded when `force=true` is passed.
Pass `dest` to write directly into a directory of your choice instead, avoiding
a duplicate copy in the scratch space.

## Master catalogue

```@docs
get_exomol_master
get_exomol_master_file
parse_exomol_master
```

## Datasets

```@docs
get_exomol_dataset
save_dataset
```
