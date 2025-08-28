
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


_parse_field(type, value) = type <: AbstractString ? value : parse(type, value)

function read_state_file(filename, def_file=replace(filename, ".states" => ".def.json"); lifetime=true, Lande=false, state_qn=[])

  def = read_def_file(def_file)
  states_def = def["dataset"]["states"]

  field_names = String[]
  field_types = DataType[]
  for field in states_def["states_file_fields"]
    push!(field_names, field["name"])
    push!(field_types, _fortran_to_type(field["ffmt"]))
  end

  states = Vector{Any}()
  open(filename, "r") do io
    for line in eachline(io)
      strings = split(line)
      @assert length(strings) == length(field_names)
      state = (;(Symbol.(field_names) .=> _parse_field.(field_types, strings))...)
      push!(states, state)
    end
  end

  return identity.(states) # fix the eltype, not sure if helpful
end

