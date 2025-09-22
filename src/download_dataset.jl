using Downloads

"""
    get_exomol_dataset(molecule::AbstractString,
                       isotopologue::AbstractString,
                       dataset::AbstractString;
                       force::Bool=false,
                       verbose::Bool=false)

Download an ExoMol dataset bundle (definition, states, and transitions
files) and cache it as an artifact.

# Arguments
- `molecule::AbstractString`: Molecular formula (e.g. `"H2O"`).
- `isotopologue::AbstractString`: Isotopologue identifier used by the
  ExoMol project (e.g. `"1H2-16O"`).
- `dataset::AbstractString`: Dataset name within the isotopologue (e.g.
  `"POKAZATEL"`).
- `force::Bool=false`: Force a re-download of the artifact even if it
  already exists locally.
- `verbose::Bool=false`: Print download progress as files are retrieved.

# Returns
- `String`: Path to the artifact directory containing the downloaded
  files.

# Examples
```julia
julia> path = get_exomol_dataset("N2", "14N2", "WCCRMT")
"/home/user/.julia/artifacts/…"
```
"""
function get_exomol_dataset(molecule, isotopologue, dataset;
  force=false, verbose=false)


  # Create artifact name
  artifact_name = _artifact_name(molecule, isotopologue, dataset)

  artifact_toml = joinpath(pkgdir(@__MODULE__), "Artifacts.toml")
  
  # This is the path to the Artifacts.toml we will manipulate

  # Query the `Artifacts.toml` file for the hash bound to the name "iris"
  # (returns `nothing` if no such binding exists)
  dataset_hash = artifact_hash(artifact_name, artifact_toml)


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
"""
    _data_url(molecule, isotopologue, dataset, type)

Construct the URL for a dataset component according to the ExoMol file
layout.
"""
_data_url(molecule, isotopologue, dataset, type) =
  "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).$(type)"

"""
    _data_filename(isotopologue, dataset, type)

Return the expected filename for a downloaded dataset component.
"""
_data_filename(isotopologue, dataset, type) =
  "$(isotopologue)__$(dataset).$(type)"

"""
    _artifact_name(molecule, isotopologue, dataset)

Create the deterministic artifact name used to cache a dataset bundle.
"""
_artifact_name(molecule, isotopologue, dataset) =
  "exomol_dataset_$(molecule)_$(isotopologue)_$(dataset)"

