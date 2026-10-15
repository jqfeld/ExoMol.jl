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
    error("Unknown Fortran format: $str")
  end
end


# Case-insensitive "nan" check without allocating.
function _is_nan_str(value)
  t = strip(value)
  ncodeunits(t) == 3 || return false
  return all(((c, r),) -> lowercase(c) == r, zip(t, "nan"))
end

function _parse_field(type, value)
  type <: AbstractString && return String(value)
  if _is_nan_str(value)
    type <: AbstractFloat && return type(NaN)
    type <: Integer       && return type(-2)  # ExoMol convention: -2 = not applicable
  end
  parse(type, value)
end

# Function barriers: compiled for the concrete column types, avoiding
# per-field dynamic dispatch in the hot loops.
_push_field!(col::Vector{T}, value) where {T} = push!(col, _parse_field(T, value))

function _assemble_rows(::Type{NT}, cols::Tuple) where {NT}
  isempty(cols) && return NT[]
  return [NT(map(c -> c[k], cols)) for k in eachindex(cols[1])]
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
function read_state_file(filename, def=read_def_file(replace(filename, r"\.states(\.bz2)?$" => ".def.json")))

  states_def = def["dataset"]["states"]

  field_names = String[]
  field_types = DataType[]
  for field in states_def["states_file_fields"]
    push!(field_names, field["name"])
    push!(field_types, _fortran_to_type(field["ffmt"]))
  end

  n = length(field_names)
  cols = Any[Vector{T}() for T in field_types]
  # Rows holding "nan" in each integer column, so they become NaN rather than
  # the -2 sentinel if the column is later promoted to Float64.
  nan_rows = [Int[] for _ in 1:n]

  _open_exomol_file(filename) do io
    for line in eachline(io)
      isempty(strip(line)) && continue
      strings = split(line)
      length(strings) == n || error("Expected $n columns, got $(length(strings)) in: $line")
      for i in 1:n
        # Some datasets declare a Hund's-case quantum number (e.g. Sigma)
        # as integer format even though it legitimately takes half-integer
        # values for odd-multiplicity (doublet, quartet, ...) electronic
        # states — promote such a field to Float64 rather than erroring.
        if field_types[i] === Int && occursin('.', strings[i])
          col = Vector{Float64}(cols[i])
          col[nan_rows[i]] .= NaN
          cols[i] = col
          field_types[i] = Float64
        end
        if field_types[i] === Int && _is_nan_str(strings[i])
          push!(nan_rows[i], length(cols[i]) + 1)
        end
        _push_field!(cols[i], strings[i])
      end
    end
  end

  NT = NamedTuple{Tuple(Symbol.(field_names)), Tuple{field_types...}}
  states = _assemble_rows(NT, Tuple(cols))

  return states
end
