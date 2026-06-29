using CodecBzip2

function _open_exomol_file(f, filename)
  if endswith(filename, ".bz2")
    stream = Bzip2DecompressorStream(open(filename))
    try
      f(stream)
    finally
      close(stream)
    end
  else
    open(f, filename)
  end
end


function _fortran_to_type(str)
  if startswith(str, "I")
    return Int
  elseif startswith(str, "F") || startswith(str, "E")
    return Float64
  elseif startswith(str, "A")
    return String
  else
    error("Unknown type")
  end
end


function _parse_field(type, value)
  type <: AbstractString && return String(value)
  if lowercase(strip(value)) == "nan"
    type <: AbstractFloat && return type(NaN)
    type <: Integer       && return type(-2)  # ExoMol convention: -2 = not applicable
  end
  parse(type, value)
end

"""
    read_state_file(filename[, def])

Read an ExoMol `.states` file and return the parsed state records.

# Arguments
- `filename::AbstractString`: Path to a `.states` or `.states.bz2` file.
- `def`: Optional dataset definition as returned by [`read_def_file`](@ref).
  When omitted the function looks for a sibling `.def.json` file.

# Returns
- `Vector{NamedTuple}`: State records with field names and types inferred from
  the dataset definition.
"""
function read_state_file(filename, def=read_def_file(replace(filename, r".states(.bz2)" => ".def.json")))

  states_def = def["dataset"]["states"]

  field_names = String[]
  field_types = DataType[]
  for field in states_def["states_file_fields"]
    push!(field_names, field["name"])
    push!(field_types, _fortran_to_type(field["ffmt"]))
  end

  NT = NamedTuple{Tuple(Symbol.(field_names)), Tuple{field_types...}}
  states = Vector{NT}()

  n = length(field_names)

  # split(line) still allocates a Vector{SubString} per line. This can be
  # eliminated by pre-computing fixed byte positions from the ffmt widths
  # (e.g. "I12" → 12, "F12.6" → 12, "ES12.4" → 12, with 1-space separators)
  # and replacing split with @view line[start:stop] slices — same approach
  # used in read_trans_file. Deferred because states files are small relative
  # to transition files, so the win is modest.
  _open_exomol_file(filename) do io
    content = read(io, String)
    for line in eachsplit(content, '\n')
      isempty(line) && continue
      strings = split(line)
      length(strings) == n || error("Expected $n columns, got $(length(strings)) in: $line")
      push!(states, NT(ntuple(i -> _parse_field(field_types[i], strings[i]), n)))
    end
  end

  return states
end
