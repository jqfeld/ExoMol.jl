using JSON
using Downloads
import Printf: format, Format
using ProgressMeter




"""
    get_exomol_dataset(molecule, isotopologue, dataset; force=false, verbose=false)

Download a specific ExoMol dataset and cache it as an artifact.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: Isotopologue identifier as used by ExoMol (e.g. `"1H2-16O"`).
- `dataset`: Dataset label (e.g. `"POKAZATEL"`).
- `force::Bool=false`: Re-download the dataset even if it already exists in the
  artifact cache.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.

# Returns
- `String`: Path to the local artifact directory that contains the dataset
  definition and accompanying data files.

The returned directory contains at least the `.def.json`, `.states.bz2` and
`.trans.bz2` files required to load the dataset into Julia using
[`load_isotopologue`](@ref).

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
      @info "The dataset is not in cache. Downloading..."
      Downloads.download(_data_url(molecule, isotopologue, dataset, "def.json"), joinpath(artifact_dir, _data_filename(isotopologue, dataset, "def.json"));
        verbose)
      def = read_def_file(joinpath(artifact_dir, _data_filename(isotopologue, dataset, "def.json")))
      @info "Obtained dataset definition file."

      Downloads.download(_data_url(molecule, isotopologue, dataset, "states.bz2"), joinpath(artifact_dir, _data_filename(isotopologue, dataset, "states.bz2"));
        verbose)
      @info "Obtained states file"


      num_trans_files = def["dataset"]["transitions"]["number_of_transition_files"]
      @info "There are $num_trans_files transition files"
      if num_trans_files == 1
        Downloads.download(_data_url(molecule, isotopologue, dataset, "trans.bz2"), joinpath(artifact_dir, _data_filename(isotopologue, dataset, "trans.bz2"));
          verbose)
      else
        max_wavenumber = Int(def["dataset"]["transitions"]["max_wavenumber"])
        del_wavenumber = Int(max_wavenumber / num_trans_files)
        num_digits = length(digits(max_wavenumber))
        fmt = Format("%0$(num_digits)d")
        p = Progress(num_trans_files)
        for lower in range(0, max_wavenumber; step=del_wavenumber)
          upper = lower + del_wavenumber
          wavenumber_range = "$(format(fmt,lower))-$(format(fmt,upper))"
          Downloads.download(_data_url(molecule, isotopologue, dataset, wavenumber_range, "trans.bz2"), 
                             joinpath(artifact_dir, _data_filename(isotopologue, dataset, wavenumber_range, "trans.bz2"));
            verbose)
          next!(p)
        end
      end

      @info "done!"
    end

    # Now bind that hash within our `Artifacts.toml`.  `force = true` means that if it already exists,
    # just overwrite with the new content-hash.  Unless the source files change, we do not expect
    # the content hash to change, so this should not cause unnecessary version control churn.
    bind_artifact!(artifact_toml, artifact_name, dataset_hash; force)
  else
    @info "Using cached dataset."
  end

  return artifact_path(dataset_hash)
end


# Construct URL following ExoMol pattern
# https://www.exomol.com/db/{molecule}/{isotopologue}/{dataset}/{isotopologue}__{dataset}.def.json
# def_url = "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).def.json"
# def_filename = "$(isotopologue)__$(dataset).def.json"
_data_url(molecule, isotopologue, dataset, type) = "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).$(type)"
_data_url(molecule, isotopologue, dataset, wavenumber_range, type) = "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset)__$(wavenumber_range).$(type)"
_data_filename(isotopologue, dataset, type) = "$(isotopologue)__$(dataset).$(type)"
_data_filename(isotopologue, dataset, wavenumber_range, type) = "$(isotopologue)__$(dataset)__$(wavenumber_range).$(type)"

_artifact_name(molecule, isotopologue, dataset) =
  "exomol_dataset_$(molecule)_$(isotopologue)_$(dataset)"

