module ExoMol


include("constants.jl")
include("definitions.jl")
include("states.jl")
include("transitions.jl")

export read_def_file
export read_state_file, read_trans_file, add_crosssection!, lookup_state_id

end
