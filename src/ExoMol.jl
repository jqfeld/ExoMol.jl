"""
    ExoMol

Utilities for downloading and parsing spectroscopic line lists from the
ExoMol project. The module exposes helpers to obtain the master
catalogue, download specific isotopologue datasets, and load state and
transition information into convenient Julia structures.
"""
module ExoMol


# include("constants.jl")

export get_exomol_master
include("download_database.jl")
include("download_dataset.jl")

include("definitions.jl")
include("states.jl")
include("transitions.jl")
include("isotopologue.jl")



export read_def_file
export read_state_file, read_trans_file

export load_isotopologue

end
