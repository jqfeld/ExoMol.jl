using JSON

"""
    read_def_file(filename)

Parse an ExoMol dataset definition (`.def.json`) file into a Julia
dictionary.

# Arguments
- `filename`: Path to the definition file. The file must be in JSON
  format and typically accompanies the downloaded dataset bundle.

# Returns
- `Dict{String,Any}`: Parsed JSON structure describing the dataset.

# Throws
- `ArgumentError`: If the file does not exist or is not a JSON document.
"""
function read_def_file(filename)
  isfile(filename) || throw(ArgumentError("Definition file not found: $filename"))
  endswith(filename, ".json") || throw(ArgumentError("Expected JSON definition file, got: $filename"))

  JSON.parsefile(filename)
end
