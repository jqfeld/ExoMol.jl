using CodecBzip2


struct Isotope{S}
  definitions::Dict
  states::Vector{S}
  transitions::Vector{Transition}
end

function load_isotope(folder)

  files = joinpath.(folder, readdir(folder))

  def_file = files[findfirst(endswith(r".def.json"), files)]

  states_files = files[findall(endswith(r".states(.bz2|$)"), files)]

  trans_files = files[findall(endswith(r".trans(.bz2|$)"), files)]


  def = read_def_file(def_file)
  states = read_state_file(states_files[1], def)
  if length(states_files) > 1
    for states_file in states_files[2:end]
      push!(states, read_state_file(states_file, def))
    end
  end

  transitions = read_trans_file(trans_files[1])
  if length(trans_files) > 1
    for trans_file in trans_files[2:end]
      push!(transitions, read_trans_file(trans_file))
    end
  end

  return Isotope(def, states, transitions)
end

