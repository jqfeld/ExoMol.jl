using CodecBzip2

"""
    Transition

Container for a radiative transition linking two energy levels in an
ExoMol dataset.

# Fields
- `upper_id::Int`: Identifier of the upper state.
- `lower_id::Int`: Identifier of the lower state.
- `A::Float64`: Einstein A-coefficient for the transition.
- `wavenumber::Float64`: Transition wavenumber in inverse centimetres.
"""
struct Transition
  upper_id::Int
  lower_id::Int
  A::Float64
  wavenumber::Float64
end

"""
    read_trans_file(filename)

Read an ExoMol `.trans` file and return a vector of [`Transition`](@ref)
objects.

# Arguments
- `filename::AbstractString`: Path to the `.trans` file. Compressed
  `.bz2` files are decompressed transparently.

# Returns
- `Vector{Transition}`: Transition records parsed from the file in the
  order they appear.
"""
function read_trans_file(filename)

  transitions = Vector{Transition}()

  process_line(strings) = push!(transitions, Transition(
    parse(Int, strings[1]),
    parse(Int, strings[2]),
    parse(Float64, strings[3]),
    parse(Float64, strings[4])
  ))

  if endswith(filename, ".bz2")
    stream = Bzip2DecompressorStream(open(filename))
    try
      for line in eachline(stream)
        process_line(split(line))
      end
    finally
      close(stream)
    end
  else
    open(filename, "r") do io
      for line in eachline(io)
        process_line(split(line))
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


