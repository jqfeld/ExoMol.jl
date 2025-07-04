using Scanf

# struct State
#   id::Int
#   energy::Float64
#   degeneracy::Int
#   J::Rational
#   energy_uncertainty::Float64
#   lifetime::Float64
#   g_Lande::Union{Float64,Nothing}
#   QN::Union{NamedTuple, Nothing}
#   source_energy::Union{String, Nothing}
#   calc_energy::Union{Float64, Nothing}
# end


function fortran_to_type(str)
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


function read_state_file(filename, def_file=replace(filename, ".states" => ".def.json"); lifetime=true, Lande=false, state_qn=[])
  # header = [
  #   :id,
  #   :E,
  #   :g,
  #   :J]
  # lifetime && push!(header, :τ)
  # Lande && push!(header, :Lande_factor)
  # append!(header, state_qn)
  # df = CSV.read(filename, DataFrame; delim=" ", ignorerepeated=true, header)
  #
  # return df

  def = read_def_file(def_file)
  states_def = def["dataset"]["states"]

  field_names = String[]
  field_types = DataType[]
  format_string = ""
  for field in states_def["states_file_fields"]
    push!(field_names, field["name"])
    push!(field_types, fortran_to_type(field["ffmt"]))
  end

  states = Vector{Dict}()
  open(filename, "r") do io
    for line in eachline(io)
      strings = split(line)
      @assert length(strings) == length(field_names)
      state = Dict()
      for i in eachindex(strings)
        if field_types[i] <: AbstractString
          state[field_names[i]] = strings[i]
        else
          state[field_names[i]] = parse(field_types[i], strings[i])
        end
      end
      push!(states, state)

    end
  end

  return states
end

function lookup_state_id(id, states)
  filter(:id => x -> x == id, states)
end
