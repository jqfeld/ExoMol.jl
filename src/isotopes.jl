struct Isotope{S}
  states::Vector{S}
  transitions::Vector{Transition}
end

function load_isotope(def_file)
  states_file = endswith(def_file, ".def.json") ? replace(def_file, ".def.json" => "states") :
    replace(def_file, ".def" => ".states")
  states = read_state_file(states_file)

  trans_file = endswith(def_file, ".def.json") ? replace(def_file, ".def.json" => "trans") :
    replace(def_file, ".def" => ".trans")
  transitions = read_trans_file(trans_file)

  return Isotope(states, transitions)
end

