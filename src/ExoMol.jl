module ExoMol


export get_exomol_master, get_exomol_master_file, parse_exomol_master
export get_exomol_dataset, save_dataset
include("download_database.jl")
include("download_dataset.jl")

include("definitions.jl")
include("states.jl")
include("transitions.jl")
include("broadening.jl")
include("isotopologue.jl")




export read_def_file
export read_state_file, read_trans_file
export read_broad_file, BroadeningLine

export load_isotopologue, read_pf_file
export Isotopologue, Transition




end
