module ExoMol


include("constants.jl")
include("definitions.jl")
include("states.jl")
include("transitions.jl")


struct Isotope
  transitions::Vector{Transition}
  states::Vector{Dict}
end


export read_def_file
export read_state_file, read_trans_file, add_crosssection!, lookup_state_id

end
