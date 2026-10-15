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

function Base.show(io::IO, t::Transition)
    print(io, "Transition($(t.upper_id) → $(t.lower_id), A=$(t.A) s⁻¹, ν̃=$(t.wavenumber) cm⁻¹)")
end

# Byte range of the next whitespace-separated field of `line` starting at
# byte `i`, or `nothing` if there is none. Fields are ASCII, so byte indices
# are valid string indices.
function _next_field(line, i)
  n = ncodeunits(line)
  while i <= n && isspace(Char(codeunit(line, i)))
    i += 1
  end
  i > n && return nothing
  j = i
  while j < n && !isspace(Char(codeunit(line, j + 1)))
    j += 1
  end
  return i:j
end

"""
    read_trans_file(filename)

Read an ExoMol `.trans` or `.trans.bz2` file and return its transition records.

Each line holds whitespace-separated columns `upper_id lower_id A [wavenumber]`.
Column widths differ between datasets, so fields are located by whitespace
rather than fixed byte positions. The wavenumber column is optional in the
ExoMol format; when it is absent the wavenumber is stored as `0.0` (and
[`load_isotopologue`](@ref) recovers it from the states). The file is read
line by line, so memory use does not grow with the file size beyond the
returned vector.

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
      r1 = _next_field(line, 1)
      isnothing(r1) && continue
      r2 = _next_field(line, last(r1) + 1)
      r3 = isnothing(r2) ? nothing : _next_field(line, last(r2) + 1)
      isnothing(r3) && error("Expected at least 3 columns in $filename, got: $line")
      r4 = _next_field(line, last(r3) + 1)
      push!(transitions, Transition(
        parse(Int,     @view line[r1]),
        parse(Int,     @view line[r2]),
        parse(Float64, @view line[r3]),
        isnothing(r4) ? 0.0 : parse(Float64, @view line[r4]),
      ))
    end
  end

  return transitions
end
