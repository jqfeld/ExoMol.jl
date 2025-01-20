
using DataFrames, CSV



function read_trans_file(filename)
  df = CSV.read(filename, DataFrame; delim=" ", ignorerepeated=true,
    header=[:upper_state, :lower_state, :A, :wavenumber]
  )
  return df
end


function add_crosssection!(trans, states)
  σs = Float64[]
  for row in eachrow(trans)
    g2 = states[states.id.==row.upper_state, :g] |> only
    g1 = states[states.id.==row.lower_state, :g] |> only
    A21 = row.A
    wn = row.wavenumber
    push!(σs, (1 / 4) * (1/(wn * 100)^2) * (g2 / g1) * A21 / (2 * π * c0 * 100)) # σ in units m^2 cm^-1
  end
  trans.σ = σs
  trans
end


