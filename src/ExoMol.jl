module ExoMol


# include("constants.jl")
include("definitions.jl")
include("states.jl")
include("transitions.jl")
include("isotopes.jl")



export read_def_file
export read_state_file, read_trans_file

export load_isotope

end
