using JSON


"""
    read_def_file(filename)

Parse an ExoMol dataset definition (`.def.json`) file.

# Arguments
- `filename::AbstractString`: Path to the definition file.  Compressed files are
  not supported and the filename must end in `.json`.

# Returns
- `Dict{String,Any}`: Parsed JSON data structure describing the dataset.
"""
function read_def_file(filename;)
  if endswith(filename, ".json")
    return JSON.parsefile(filename)
  end
  
end
