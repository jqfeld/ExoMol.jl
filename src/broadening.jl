"""
    BroadeningLine(code, gamma_L, n_air, q1, q2)

Single record from an ExoMol `.broad` file.

# Fields
- `code::String`: Recipe label (e.g. `"a0"`, `"a1"`, `"j"`, `"jj"`).
- `gamma_L::Float64`: Lorentzian HWHM coefficient (cm⁻¹/atm).
- `n_air::Float64`: Temperature exponent.
- `q1::Float64`: Primary quantum number for recipe lookup (`NaN` if absent).
- `q2::Float64`: Secondary quantum number for recipe lookup (`NaN` if absent).
"""
struct BroadeningLine
  code::String
  gamma_L::Float64
  n_air::Float64
  q1::Float64
  q2::Float64
end

"""
    read_broad_file(filename)

Read an ExoMol `.broad` file and return its records.

Each line has the fixed columns `code gamma_L n_air` followed by zero, one,
or two optional quantum-number columns. Missing quantum numbers are stored as
`NaN`.

# Arguments
- `filename::AbstractString`: Path to the `.broad` file.

# Returns
- `Vector{BroadeningLine}`: Parsed broadening records.
"""
function read_broad_file(filename)
  records = BroadeningLine[]
  for line in eachline(filename)
    parts = split(line)
    length(parts) < 3 && continue
    push!(records, BroadeningLine(
      String(parts[1]),
      parse(Float64, parts[2]),
      parse(Float64, parts[3]),
      length(parts) >= 4 ? parse(Float64, parts[4]) : NaN,
      length(parts) >= 5 ? parse(Float64, parts[5]) : NaN,
    ))
  end
  return records
end
