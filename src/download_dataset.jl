using JSON
using Downloads




"""
    get_exomol_dataset(molecule::String, isotopologue::String, dataset::String; 
                           force::Bool=false, cache_dir::Union{String,Nothing}=nothing)

Download a specific ExoMol dataset definition file as an artifact.

# Arguments
- `molecule::String`: Molecule formula (e.g., "H2O", "CO2", "N2")
- `isotopologue::String`: Isotopologue identifier (e.g., "1H2-16O", "14N2")
- `dataset::String`: Dataset name (e.g., "POKAZATEL", "WCCRMT")
- `force::Bool=false`: Force re-download even if artifact exists
- `cache_dir::Union{String,Nothing}=nothing`: Optional custom cache directory

# Returns
- `String`: Path to the downloaded dataset definition file

# Examples
```julia
# Download N2 WCCRMT dataset
dataset_path = download_exomol_dataset("N2", "14N2", "WCCRMT")

# Download H2O POKAZATEL dataset with force reload
dataset_path = download_exomol_dataset("H2O", "1H2-16O", "POKAZATEL", force=true)
```

# Notes
Downloads the JSON format dataset definition file, which contains metadata, and 
the actual spectroscopic data files (.states, .trans, etc.).
"""
function get_exomol_dataset(molecule, isotopologue, dataset;
  force=false,verbose=false)


  # Create artifact name
  artifact_name = _artifact_name(molecule, isotopologue, dataset)

  artifact_toml = joinpath(pkgdir(@__MODULE__), "Artifacts.toml")
  
  # This is the path to the Artifacts.toml we will manipulate

  # Query the `Artifacts.toml` file for the hash bound to the name "iris"
  # (returns `nothing` if no such binding exists)
  dataset_hash = artifact_hash(artifact_name, artifact_toml)

  @info dataset_hash
  @info artifact_exists(dataset_hash)

  # If the name was not bound, or the hash it was bound to does not exist, create it!
  if isnothing(dataset_hash) || !artifact_exists(dataset_hash) || force
    # create_artifact() returns the content-hash of the artifact directory once we're finished creating it
    dataset_hash = create_artifact() do artifact_dir
      # We create the artifact by simply downloading a few files into the new artifact directory
      for type in ["def.json", "states.bz2", "trans.bz2"]
        Downloads.download(_data_url(molecule, isotopologue, dataset, type), joinpath(artifact_dir, _data_filename(isotopologue,dataset,type));
                 verbose)
      end
    end

    # Now bind that hash within our `Artifacts.toml`.  `force = true` means that if it already exists,
    # just overwrite with the new content-hash.  Unless the source files change, we do not expect
    # the content hash to change, so this should not cause unnecessary version control churn.
    bind_artifact!(artifact_toml, artifact_name, dataset_hash; force)
  end

  return artifact_path(dataset_hash)
end


  # Construct URL following ExoMol pattern
  # https://www.exomol.com/db/{molecule}/{isotopologue}/{dataset}/{isotopologue}__{dataset}.def.json
  # def_url = "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).def.json"
  # def_filename = "$(isotopologue)__$(dataset).def.json"
_data_url(molecule, isotopologue, dataset, type) = "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).$(type)"
_data_filename(isotopologue, dataset, type) = "$(isotopologue)__$(dataset).$(type)"

_artifact_name(molecule, isotopologue, dataset) =
  "exomol_dataset_$(molecule)_$(isotopologue)_$(dataset)"

