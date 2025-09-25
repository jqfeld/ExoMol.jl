using Pkg.Artifacts
using JSON


"""
    get_exomol_master_file(; force=false)

Download the ExoMol master catalogue as an artifact and return its local path.

# Arguments
- `force::Bool=false`: Re-download the catalogue even if it already exists in the
  artifact cache.

# Returns
- `String`: Absolute path to the downloaded `exomol.all.json` file.

This function is primarily intended to be used internally.  For direct access to
the parsed catalogue use [`get_exomol_master`](@ref).
"""
function get_exomol_master_file(; force=false)
  artifact_toml = joinpath(pkgdir(@__MODULE__), "Artifacts.toml")

  # This is the path to the Artifacts.toml we will manipulate

  # Query the `Artifacts.toml` file for the hash bound to the name "iris"
  # (returns `nothing` if no such binding exists)
  exomol_master_hash = artifact_hash("master", artifact_toml)

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
    bind_artifact!(artifact_toml, "exomol_master", exomol_master_hash)
  end

  joinpath(artifact_path(exomol_master_hash), "exomol.all.json")
end


"""
    parse_exomol_master(filepath::String)

Parse the ExoMol master file and return structured data.

# Arguments  
- `filepath::String`: Path to the master file (JSON format)

# Returns
- Returns the parsed JSON structure

# Examples
```julia
master_path = download_exomol_master()
data = parse_exomol_master(master_path)
```
"""
function parse_exomol_master(filepath::String)
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

Retrieve the ExoMol master catalogue as a parsed JSON object.

# Arguments
- `force::Bool=false`: Re-download the catalogue even if it already exists in the
  artifact cache.

# Returns
- `Dict{String,Any}`: Parsed contents of the ExoMol master catalogue.
"""
function get_exomol_master(; force=false)
  parse_exomol_master(get_exomol_master_file(; force))
end
