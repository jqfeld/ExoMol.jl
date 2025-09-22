using CodecBzip2

"""
    _fortran_to_type(str)

Convert the Fortran-style field descriptor found in ExoMol definition
files into the corresponding Julia type.

The definition files use the same abbreviations as Fortran format
strings (for example `I6` for integer fields, `F12.6` for floating point
values, and `A15` for character data).  Only the prefix is relevant for
the conversion – the width and precision components are ignored because
the individual values are parsed from space separated columns.

# Throws
- `ArgumentError` if the descriptor does not start with a known prefix.
"""
function _fortran_to_type(str)
  if startswith(str, "I")
    return Int
  elseif startswith(str, "F") || startswith(str, "E")
    return Float64
  elseif startswith(str, "A")
    return String
  else
    throw(ArgumentError("Unknown field descriptor: $str"))
  end
end

"""
    _default_state_definition_path(path)

Derive the path to the dataset definition JSON file from the provided
state file path.

Both compressed (`.states.bz2`) and uncompressed (`.states`) files are
supported.  The returned path simply replaces the trailing state suffix
with `.def.json` without checking for existence – callers are expected to
handle missing files.
"""
_default_state_definition_path(path::AbstractString) =
  replace(path, r"\.states(?:\.bz2)?$" => ".def.json")


"""
    _parse_field(type, value)

Convert the raw string `value` obtained from a `.states` line into the
target `type` while preserving string fields verbatim.
"""
_parse_field(type, value) = type <: AbstractString ? value : parse(type, value)

"""
    read_state_file(filename[, def])

Read an ExoMol `.states` file into a vector of named tuples whose fields
mirror the dataset definition.

# Arguments
- `filename::AbstractString`: Path to the `.states` file. Compressed
  `.bz2` files are automatically decompressed on the fly.
- `def::Dict=read_def_file(_default_state_definition_path(filename))`:
  Optional dataset definition dictionary.  When omitted the
  corresponding `.def.json` file is read from disk using the same stem as
  the state file.

# Returns
- `Vector{NamedTuple}`: State records with columns typed according to
  the definition metadata.

# Throws
- `ArgumentError`: If the dataset definition does not describe any state
  fields.
"""
function read_state_file(filename,
  def=read_def_file(_default_state_definition_path(filename)))

  states_def = def["dataset"]["states"]

  field_entries = states_def["states_file_fields"]
  isempty(field_entries) && throw(ArgumentError("Definition does not contain any state fields."))

  field_names = Tuple(Symbol(field["name"]) for field in field_entries)
  field_types = Tuple(_fortran_to_type(field["ffmt"]) for field in field_entries)

  state_type = NamedTuple{field_names, field_types}
  states = Vector{state_type}()

  process_line = let field_types=field_types, field_names=field_names
    function (line)
      strings = split(line)
      @assert length(strings) == length(field_names)
      values = ntuple(i -> _parse_field(field_types[i], strings[i]), length(field_types))
      push!(states, state_type(values))
    end
  end

  if endswith(filename, ".bz2")
    stream = Bzip2DecompressorStream(open(filename))
    try
      for line in eachline(stream)
        process_line(line)
      end
    finally
      close(stream)
    end
  else
    open(filename, "r") do io
      for line in eachline(io)
        process_line(line)
      end
    end
  end

  states
end

