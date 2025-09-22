using CodecBzip2
using Base.Iterators

"""
    Isotopologue{S}

Representation of an ExoMol isotopologue dataset.

# Type parameters
- `S`: Type of the individual state records, typically a `NamedTuple`
  whose fields match the dataset definition.

# Fields
- `definitions::Dict{String,Any}`: Metadata extracted from the
  `.def.json` file.
- `states::Vector{S}`: Parsed state records.
- `transitions::Vector{Transition}`: Radiative transitions defined for
  the isotopologue.
"""
struct Isotopologue{S}
  definitions::Dict
  states::Vector{S}
  transitions::Vector{Transition}
end

"""
    load_isotopologue(folder)

Load a previously downloaded isotopologue directory produced by
[`get_exomol_dataset`](@ref) and return a structured object containing
its definition, states, and transitions.  Multiple state or transition
files are concatenated in lexicographical order to preserve the dataset's
canonical ordering.

# Arguments
- `folder::AbstractString`: Path to the dataset directory containing
  `.def.json`, `.states` (optionally compressed), and `.trans` files.

# Returns
- `Isotopologue`: Structured representation of the dataset contents.

# Throws
- `ArgumentError`: If any of the required files are missing.
"""
function load_isotopologue(folder)

  files = joinpath.(folder, readdir(folder))

  def_index = findfirst(endswith(r".def.json"), files)
  isnothing(def_index) && throw(ArgumentError("No definition file (.def.json) found in $folder"))
  def_file = files[def_index]

  states_files = sort(files[findall(endswith(r".states(.bz2|$)"), files)])
  isempty(states_files) && throw(ArgumentError("No state files found in $folder"))

  trans_files = sort(files[findall(endswith(r".trans(.bz2|$)"), files)])
  isempty(trans_files) && throw(ArgumentError("No transition files found in $folder"))

  def = read_def_file(def_file)

  states = read_state_file(first(states_files), def)
  for file in drop(states_files, 1)
    append!(states, read_state_file(file, def))
  end

  transitions = read_trans_file(first(trans_files))
  for file in drop(trans_files, 1)
    append!(transitions, read_trans_file(file))
  end

  Isotopologue(def, states, transitions)
end

