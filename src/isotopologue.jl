using CodecBzip2


"""
    Isotopologue(definitions, states, transitions)

Composite type holding all data associated with an ExoMol isotopologue.

# Fields
- `definitions::Dict`: Dataset definition metadata.
- `states::Vector`: Parsed molecular states (typically `NamedTuple`s).
- `transitions::Vector{Transition}`: Transition catalogue.
"""
struct Isotopologue{S}
  definitions::Dict
  states::Vector{S}
  transitions::Vector{Transition}
end

"""
    load_isotopologue(folder)

Load an isotopologue from a directory containing ExoMol dataset files.

# Arguments
- `folder::AbstractString`: Directory holding `.def.json`, `.states*` and
  `.trans*` files belonging to an ExoMol dataset.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(folder)

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

  return Isotopologue(def, states, transitions)
end

"""
    load_isotopologue(molecule, isotopologue, dataset)

Convenience method that downloads an ExoMol dataset (if necessary) and loads it
into an [`Isotopologue`](@ref) struct.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: ExoMol isotopologue identifier.
- `dataset`: Dataset label.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(molecule, isotopologue, dataset)
  ds = ExoMol.get_exomol_dataset(molecule, isotopologue, dataset)
  load_isotopologue(ds)
end
