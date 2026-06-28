using CodecBzip2
using DataInterpolations


"""
    Isotopologue(definitions, states, transitions, partition_function)

Composite type holding all data associated with an ExoMol isotopologue.

# Fields
- `definitions::Dict`: Dataset definition metadata.
- `states::Vector`: Parsed molecular states (typically `NamedTuple`s).
- `transitions::Vector{Transition}`: Transition catalogue.
- `partition_function`: `LinearInterpolation` of Q(T) over temperature, or
  `nothing` if no partition function file was found.
"""
struct Isotopologue{S}
  definitions::Dict
  states::Vector{S}
  transitions::Vector{Transition}
  partition_function
end

"""
    load_isotopologue(folder)

Load an isotopologue from a directory containing ExoMol dataset files.

# Arguments
- `folder::AbstractString`: Directory holding `.def.json`, `.states*`, `.trans*`,
  and optionally `.pf` files belonging to an ExoMol dataset.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(folder)

  files = joinpath.(folder, readdir(folder))

  def_file = files[findfirst(endswith(r".def.json"), files)]
  states_files = files[findall(endswith(r".states(.bz2|$)"), files)]
  trans_files = files[findall(endswith(r".trans(.bz2|$)"), files)]
  pf_files = files[findall(endswith(".pf"), files)]

  def = read_def_file(def_file)

  states = read_state_file(states_files[1], def)
  for states_file in states_files[2:end]
    append!(states, read_state_file(states_file, def))
  end

  transitions = read_trans_file(trans_files[1])
  for trans_file in trans_files[2:end]
    append!(transitions, read_trans_file(trans_file))
  end

  partition_function = isempty(pf_files) ? nothing : read_pf_file(pf_files[1])

  return Isotopologue(Dict(def), states, transitions, partition_function)
end

"""
    read_pf_file(path)

Parse an ExoMol partition function file (`.pf`) and return a `LinearInterpolation`
of Q(T) as a function of temperature.

# Arguments
- `path::AbstractString`: Path to the `.pf` file.

# Returns
- `LinearInterpolation`: Callable interpolant; evaluate with `itp(T)`.
"""
function read_pf_file(path)
  T_vals = Float64[]
  Q_vals = Float64[]
  for line in eachline(path)
    parts = split(line)
    length(parts) < 2 && continue
    push!(T_vals, parse(Float64, parts[1]))
    push!(Q_vals, parse(Float64, parts[2]))
  end
  LinearInterpolation(Q_vals, T_vals)
end

"""
    load_isotopologue(molecule, isotopologue, dataset; wn_range=nothing, force=false, verbose=false)

Convenience method that downloads an ExoMol dataset (if necessary) and loads it
into an [`Isotopologue`](@ref) struct.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: ExoMol isotopologue identifier.
- `dataset`: Dataset label.
- `wn_range`: Optional wavenumber range `(wn_min, wn_max)` in cm⁻¹ to restrict
  which transition files are downloaded and loaded.
- `force::Bool=false`: Re-download files even if cached.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(molecule, isotopologue, dataset; wn_range=nothing, force=false, verbose=false)
  ds = ExoMol.get_exomol_dataset(molecule, isotopologue, dataset; wn_range, force, verbose)
  load_isotopologue(ds)
end

"""
    load_isotopologue(molecule, isotopologue; wn_range=nothing, force=false, verbose=false)

Like the three-argument form but automatically selects the dataset marked
`recommended` in the ExoMol API.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: ExoMol isotopologue identifier (e.g. `"1H2-16O"`).
- `wn_range`: Optional wavenumber range `(wn_min, wn_max)` in cm⁻¹.
- `force::Bool=false`: Re-download files even if cached.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(molecule, isotopologue; wn_range=nothing, force=false, verbose=false)
  dataset = ExoMol._recommended_dataset(molecule, isotopologue)
  @info "Using recommended dataset: $dataset"
  load_isotopologue(molecule, isotopologue, dataset; wn_range, force, verbose)
end
