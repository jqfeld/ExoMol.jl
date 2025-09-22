using Pkg.Artifacts
using JSON

const MASTER_ARTIFACT_NAME = "exomol_master"

"""
    get_exomol_master_file(; force=false)

Ensure that the ExoMol master catalogue is present as an artifact and
return the local path to the downloaded JSON file.

# Arguments
- `force::Bool=false`: When `true`, re-download the catalogue even if it
  is already present in the artifact cache.

# Returns
- `String`: Path to the cached `exomol.all.json` master file.

# Notes
The master file provides metadata for every molecule and isotopologue in
the ExoMol database and is required before individual datasets can be
downloaded.
"""
function get_exomol_master_file(; force=false)
  artifact_toml = joinpath(pkgdir(@__MODULE__), "Artifacts.toml")

  # This is the path to the Artifacts.toml we will manipulate

  # Query the `Artifacts.toml` file for the hash bound to the name "iris"
  # (returns `nothing` if no such binding exists)
  exomol_master_hash = artifact_hash(MASTER_ARTIFACT_NAME, artifact_toml)

  # If the name was not bound, or the hash it was bound to does not exist, create it!
  if exomol_master_hash == nothing || !artifact_exists(exomol_master_hash) || force
    # create_artifact() returns the content-hash of the artifact directory once we're finished creating it
    exomol_master_hash = create_artifact() do artifact_dir
      # We create the artifact by simply downloading a few files into the new artifact directory
      exomol_master_url = "https://www.exomol.com/db/exomol.all.json"
      download(exomol_master_url, joinpath(artifact_dir, "exomol.all.json"))
    end

    # Now bind that hash within our `Artifacts.toml`.  `force = true` means that if it already exists,
    # just overwrite with the new content-hash.  Unless the source files change, we do not expect
    # the content hash to change, so this should not cause unnecessary version control churn.
    bind_artifact!(artifact_toml, MASTER_ARTIFACT_NAME, exomol_master_hash)
  end

  joinpath(artifact_path(exomol_master_hash), "exomol.all.json")
end


"""
    parse_exomol_master(filepath::AbstractString)

Parse the ExoMol master file and return structured data.

# Arguments
- `filepath::AbstractString`: Path to the master file (JSON format).

# Returns
- `Dict{String,Any}`: Parsed JSON structure describing all available
  molecules and isotopologues.

# Examples
```julia
master_path = get_exomol_master_file()
data = parse_exomol_master(master_path)
```
"""
function parse_exomol_master(filepath::AbstractString)
  if !isfile(filepath)
    throw(ArgumentError("Master file not found: $filepath"))
  end

  # Parse the JSON file
  if endswith(filepath, ".json")
    return JSON.parsefile(filepath)
  else
    throw(ArgumentError("Expected JSON file, got: $filepath"))
  end
end


"""
    get_exomol_master(; force=false)

Download (if necessary) and parse the ExoMol master file.

# Arguments
- `force::Bool=false`: Forwarded to [`get_exomol_master_file`](@ref) to
  force re-downloading the file.

# Returns
- `Dict{String,Any}`: Parsed representation of the ExoMol master JSON
  document.
"""
function get_exomol_master(; force=false)
  parse_exomol_master(get_exomol_master_file(; force))
end
