```@meta
CurrentModule = ExoMol
```

# Download API

These functions handle fetching data from the ExoMol web API and caching it in
Julia's scratch space (`~/.julia/scratchspaces/`). The cache persists across
Julia sessions; files are only re-downloaded when `force=true` is passed.

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
