
function read_state_file(filename; lifetime=true, Lande=false, state_qn=[])
  header = [
    :id,
    :E,
    :g,
    :J]
  lifetime && push!(header, :τ)
  Lande && push!(header, :Lande_factor)
  append!(header, state_qn)
  df = CSV.read(filename, DataFrame; delim=" ", ignorerepeated=true, header)

  return df
end

function lookup_state_id(id, states)
  filter(:id => x -> x == id, states)
end
