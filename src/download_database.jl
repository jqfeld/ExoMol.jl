using Scratch, Downloads
using JSON


"""
    get_exomol_master_file(; force=false)

Download the ExoMol master catalogue to the package scratch space and return
its local path. Use [`get_exomol_master`](@ref) to get the parsed catalogue
directly.

# Arguments
- `force::Bool=false`: Re-download the catalogue even if already cached.

# Returns
- `String`: Absolute path to the cached `exomol.all.json` file.
"""
function get_exomol_master_file(; force=false)
  cache_dir = @get_scratch!("exomol_master")
  filepath = joinpath(cache_dir, "exomol.all.json")

  if !isfile(filepath) || force
    _download_with_progress("https://www.exomol.com/db/exomol.all.json", filepath;
      desc="  ExoMol catalogue:")
  end

  return filepath
end


"""
    parse_exomol_master(filepath)

Parse a locally cached ExoMol master catalogue file.

# Arguments
- `filepath::AbstractString`: Path to a `.json` master catalogue file.

# Returns
- `Dict{String,Any}`: Parsed catalogue contents.
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

Download (if necessary) and return the ExoMol master catalogue as a parsed
`Dict`. The catalogue lists all available molecules, isotopologues, and
datasets.

# Arguments
- `force::Bool=false`: Re-download the catalogue even if already cached.

# Returns
- `Dict{String,Any}`: Parsed contents of `exomol.all.json`.
"""
function get_exomol_master(; force=false)
  parse_exomol_master(get_exomol_master_file(; force))
end
