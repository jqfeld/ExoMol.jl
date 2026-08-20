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

"""
    read_trans_file(filename)

Read an ExoMol `.trans` or `.trans.bz2` file and return its transition records.

The upper/lower state ID columns are parsed by fixed byte position (1–12,
14–25) — stable across every dataset seen so far — avoiding a per-line
allocation for those two fields. The A coefficient and wavenumber columns
are parsed via `split` on the line's remainder instead: their padding width
is *not* fixed across datasets (OH/MYTHOS pads the A
field by 2 spaces where e.g. SiO/EBJT pads by 1, silently truncating the A
column's last digit under a hardcoded byte offset tuned to one dataset's
width), and `.def.json`'s `"transitions"` section, unlike `"states"`, does
not declare per-field widths to read that padding from.

# Arguments
- `filename::AbstractString`: Path to a `.trans` or `.trans.bz2` file.

# Returns
- `Vector{Transition}`: Parsed transition records.
"""
function read_trans_file(filename, n=0)

  transitions = Vector{Transition}()
  n > 0 && sizehint!(transitions, n)

  _open_exomol_file(filename) do io
    content = read(io, String)
    for line in eachsplit(content, '\n')
      isempty(line) && continue
      rest = split(@view line[26:end])
      push!(transitions, Transition(
        parse(Int,     @view line[1:12]),
        parse(Int,     @view line[14:25]),
        parse(Float64, rest[1]),
        length(rest) >= 2 ? parse(Float64, rest[2]) : 0.0
      ))
    end
  end

  return transitions
end
