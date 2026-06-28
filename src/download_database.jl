using Scratch, Downloads
using JSON


"""
    get_exomol_master_file(; force=false)

Download the ExoMol master catalogue and return its local path.

# Arguments
- `force::Bool=false`: Re-download the catalogue even if it already exists in the
  local cache.

# Returns
- `String`: Absolute path to the downloaded `exomol.all.json` file.

This function is primarily intended to be used internally.  For direct access to
the parsed catalogue use [`get_exomol_master`](@ref).
"""
function get_exomol_master_file(; force=false)
  cache_dir = @get_scratch!("exomol_master")
  filepath = joinpath(cache_dir, "exomol.all.json")

  if !isfile(filepath) || force
    @info "Downloading ExoMol master catalogue..."
    Downloads.download("https://www.exomol.com/db/exomol.all.json", filepath)
  end

  return filepath
end


"""
    parse_exomol_master(filepath::String)

Parse the ExoMol master file and return structured data.

# Arguments
- `filepath::String`: Path to the master file (JSON format).

# Returns
- Returns the parsed JSON structure.
"""
function parse_exomol_master(filepath::String)
  if !isfile(filepath)
    throw(ArgumentError("Master file not found: $filepath"))
  end

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
  local cache.

# Returns
- `Dict{String,Any}`: Parsed contents of the ExoMol master catalogue.
"""
function get_exomol_master(; force=false)
  parse_exomol_master(get_exomol_master_file(; force))
end
