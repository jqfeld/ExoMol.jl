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
function read_trans_file(filename, n=0)

  transitions = Vector{Transition}()
  n > 0 && sizehint!(transitions, n)

  _open_exomol_file(filename) do io
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

  return transitions
end
