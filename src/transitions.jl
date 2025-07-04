
using DataFrames, CSV

struct Transition
  upper_id::Int
  lower_id::Int
  A::Float64
  wavenumber::Float64
end

function read_trans_file(filename)
  transitions = Vector{Transition}()
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

  return transitions

  # df = CSV.read(filename, DataFrame; delim=" ", ignorerepeated=true,
  #   header=[:upper_state, :lower_state, :A, :wavenumber]
  # )
  # return df
end


function add_crosssection!(trans, states)
  σs = Float64[]
  for row in eachrow(trans)
    g2 = states[states.id.==row.upper_state, :g] |> only
    g1 = states[states.id.==row.lower_state, :g] |> only
    A21 = row.A
    wn = row.wavenumber
    push!(σs, (1 / 4) * (1 / (wn * 100)^2) * (g2 / g1) * A21 / (2 * π * c0 * 100)) # σ in units m^2 cm^-1
  end
  trans.σ = σs
  trans
end


