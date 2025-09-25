using CodecBzip2

"""
    Transition(upper_id, lower_id, A, wavenumber)

Container holding a single transition from an ExoMol `.trans` file.

# Fields
- `upper_id::Int`: Identifier of the upper energy level.
- `lower_id::Int`: Identifier of the lower energy level.
- `A::Float64`: Einstein A coefficient (s⁻¹).
- `wavenumber::Float64`: Transition wavenumber (cm⁻¹).
"""
struct Transition
  upper_id::Int
  lower_id::Int
  A::Float64
  wavenumber::Float64
end

"""
    read_trans_file(filename)

Read an ExoMol `.trans` file and return the transitions contained in it.

# Arguments
- `filename::AbstractString`: Path to a `.trans` or `.trans.bz2` file.

# Returns
- `Vector{Transition}`: Parsed transition records.
"""
function read_trans_file(filename)

  transitions = Vector{Transition}()

  if endswith(filename, ".bz2")
    stream = Bzip2DecompressorStream(open(filename))
    for line in eachline(stream)
        strings = split(line)
        push!(transitions, Transition(
          parse(Int, strings[1]),
          parse(Int, strings[2]),
          parse(Float64, strings[3]),
          parse(Float64, strings[4])
        ))
    end
    close(stream)
  else
    open(filename, "r") do io
      for line in eachline(io)
        strings = split(line)
        push!(transitions, Transition(
          parse(Int, strings[1]),
          parse(Int, strings[2]),
          parse(Float64, strings[3]),
          parse(Float64, strings[4])
        ))
      end
    end
  end

  return transitions

end


# function add_crosssection!(trans, states)
#   σs = Float64[]
#   for row in eachrow(trans)
#     g2 = states[states.id.==row.upper_state, :g] |> only
#     g1 = states[states.id.==row.lower_state, :g] |> only
#     A21 = row.A
#     wn = row.wavenumber
#     push!(σs, (1 / 4) * (1 / (wn * 100)^2) * (g2 / g1) * A21 / (2 * π * c0 * 100)) # σ in units m^2 cm^-1
#   end
#   trans.σ = σs
#   trans
# end


