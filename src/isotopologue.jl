using DataInterpolations


"""
    Isotopologue{S, P}(definitions, states, transitions, partition_function, broadeners)

Composite type holding all data associated with an ExoMol isotopologue.

# Fields
- `definitions::Dict`: Dataset definition metadata.
- `states::Vector`: Parsed molecular states (typically `NamedTuple`s).
- `transitions::Vector{Transition}`: Transition catalogue.
- `partition_function`: `LinearInterpolation` of Q(T) over temperature, or
  `nothing` if no partition function file was found.
- `broadeners::Dict{String, Vector{BroadeningLine}}`: Pressure broadening
  records keyed by broadener name (e.g. `"H2"`, `"He"`). Empty for datasets
  with no broadening files.
"""
struct Isotopologue{S, P}
  definitions::Dict
  states::Vector{S}
  transitions::Vector{Transition}
  partition_function::P
  broadeners::Dict{String, Vector{BroadeningLine}}
end

_fmt(n::Integer) = reverse(join(Iterators.partition(reverse(string(n)), 3), ','))

function _read_broadeners(broad_files)
  broadeners = Dict{String, Vector{BroadeningLine}}()
  for bf in broad_files
    name = replace(basename(bf), r"^.+__(.+)\.broad$" => s"\1")
    broadeners[name] = read_broad_file(bf)
  end
  return broadeners
end

"""
    load_isotopologue(folder; wn_range=nothing)

Load an isotopologue from a directory containing ExoMol dataset files.

# Arguments
- `folder::AbstractString`: Directory holding `.def.json`, `.states*`, `.trans*`,
  and optionally `.pf` files belonging to an ExoMol dataset.
- `wn_range`: Optional wavenumber range `(wn_min, wn_max)` in cm⁻¹ to restrict
  which transition files are loaded. Files that do not overlap the range are skipped.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(folder::AbstractString; wn_range=nothing)

  files = joinpath.(folder, readdir(folder))

  def_idx = findfirst(endswith(r".def.json"), files)
  isnothing(def_idx) && error("No .def.json file found in $folder")
  def_file = files[def_idx]
  states_files = files[findall(endswith(r".states(.bz2|$)"), files)]
  pf_files = files[findall(endswith(".pf"), files)]

  def = read_def_file(def_file)

  all_trans = files[findall(endswith(r".trans(.bz2|$)"), files)]
  if isnothing(wn_range)
    trans_files = all_trans
  else
    iso_slug    = def["isotopologue"]["iso_slug"]
    dataset_name = def["dataset"]["name"]
    trans_files = filter(f -> _trans_in_wn_range(basename(f), iso_slug, dataset_name, wn_range), all_trans)
  end

  states = read_state_file(states_files[1], def)
  for states_file in states_files[2:end]
    append!(states, read_state_file(states_file, def))
  end

  n_trans = get(get(get(def, "dataset", Dict()), "transitions", Dict()), "number_of_transitions", 0)
  # Only use n_trans as a per-file hint when loading the full unfiltered set;
  # with a filter active the subset size is unknown, so let read_trans_file grow naturally.
  n_per_file = (isempty(trans_files) || !isnothing(wn_range)) ? 0 : n_trans ÷ length(trans_files)
  chunks = Vector{Vector{Transition}}(undef, length(trans_files))
  @sync for (i, f) in enumerate(trans_files)
    Threads.@spawn chunks[i] = read_trans_file(f, n_per_file)
  end
  transitions = Vector{Transition}()
  sizehint!(transitions, sum(length(c) for c in chunks; init=0))
  for chunk in chunks
    append!(transitions, chunk)
  end

  partition_function = isempty(pf_files) ? nothing : read_pf_file(pf_files[1])

  broad_files = files[findall(endswith(".broad"), files)]

  return Isotopologue(Dict(def), states, transitions, partition_function, _read_broadeners(broad_files))
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
    load_isotopologue(molecule, isotopologue, dataset; wn_range=nothing, force=false, verbose=false, broad_fallback=false)

Download an ExoMol dataset (if not already cached) and load it into an
[`Isotopologue`](@ref) struct.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: ExoMol isotopologue identifier (e.g. `"1H2-16O"`).
- `dataset`: Dataset label (e.g. `"POKAZATEL"`).
- `wn_range`: Optional wavenumber range `(wn_min, wn_max)` in cm⁻¹. Only
  transition files that overlap the range are downloaded and loaded.
- `force::Bool=false`: Re-download files even if already cached.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.
- `broad_fallback`: When `true`, if the dataset has no broadening files the
  package will attempt to borrow them from another cached isotopologue of the
  same molecule. Pass an isotopologue slug string (e.g. `"1H2-16O"`) to target a
  specific isotopologue instead of auto-detecting one.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(molecule, isotopologue, dataset;
    wn_range=nothing, force=false, verbose=false, broad_fallback=false)
  ds = ExoMol.get_exomol_dataset(molecule, isotopologue, dataset; wn_range, force, verbose)
  iso = load_isotopologue(ds; wn_range)
  (broad_fallback === false || !isempty(iso.broadeners)) && return iso
  response = ExoMol._fetch_linelist_api(molecule)
  return _load_with_broad_fallback(iso, molecule, isotopologue, ds, broad_fallback, response; force, verbose)
end

"""
    load_isotopologue(molecule, isotopologue; wn_range=nothing, force=false, verbose=false, broad_fallback=false)

Like the three-argument form but automatically selects the dataset marked
`recommended` in the ExoMol API.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: ExoMol isotopologue identifier (e.g. `"1H2-16O"`).
- `wn_range`: Optional wavenumber range `(wn_min, wn_max)` in cm⁻¹. Only
  transition files that overlap the range are downloaded and loaded.
- `force::Bool=false`: Re-download files even if already cached.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.
- `broad_fallback`: When `true`, if the dataset has no broadening files the
  package will attempt to borrow them from another cached isotopologue of the
  same molecule. Pass an isotopologue slug string to target a specific
  isotopologue instead of auto-detecting one.

# Returns
- `Isotopologue`: Parsed isotopologue data ready for analysis.
"""
function load_isotopologue(molecule, isotopologue;
    wn_range=nothing, force=false, verbose=false, broad_fallback=false)
  dataset, response = ExoMol._recommended_dataset(molecule, isotopologue)
  @info "Using recommended dataset: $dataset"
  ds = ExoMol.get_exomol_dataset(molecule, isotopologue, dataset; wn_range, force, verbose, _response=response)
  iso = load_isotopologue(ds; wn_range)
  (broad_fallback === false || !isempty(iso.broadeners)) && return iso
  return _load_with_broad_fallback(iso, molecule, isotopologue, ds, broad_fallback, response; force, verbose)
end

function Base.show(io::IO, iso::Isotopologue)
    iso_slug = get(get(iso.definitions, "isotopologue", Dict()), "iso_slug", "?")
    ds_name  = get(get(iso.definitions, "dataset",      Dict()), "name",     "?")
    print(io, "Isotopologue($iso_slug/$ds_name, $(_fmt(length(iso.states))) states, $(_fmt(length(iso.transitions))) transitions)")
end

function Base.show(io::IO, ::MIME"text/plain", iso::Isotopologue)
    iso_slug = get(get(iso.definitions, "isotopologue", Dict()), "iso_slug", "?")
    ds_name  = get(get(iso.definitions, "dataset",      Dict()), "name",     "?")
    println(io, "Isotopologue: $iso_slug / $ds_name")
    println(io, "  States:              ", _fmt(length(iso.states)))
    println(io, "  Transitions:         ", _fmt(length(iso.transitions)))
    if isnothing(iso.partition_function)
        println(io, "  Partition function:  none")
    else
        T = iso.partition_function.t
        println(io, "  Partition function:  T ∈ [$(first(T)), $(last(T))] K")
    end
    if isempty(iso.broadeners)
        print(io,   "  Broadeners:          none")
    else
        parts = ["$k ($(_fmt(length(v))) lines)" for (k, v) in sort!(collect(iso.broadeners))]
        print(io,   "  Broadeners:          ", join(parts, ", "))
    end
end

function _load_with_broad_fallback(iso, molecule, isotopologue, dataset_dir, broad_fallback, response; force, verbose)
  if broad_fallback isa AbstractString
    fallback_slug = broad_fallback
    fallback_def = ExoMol._fetch_def_for_iso(molecule, fallback_slug, response)
    if isnothing(fallback_def)
      @warn "Could not retrieve broadening definition for $fallback_slug; skipping broadening fallback."
      return iso
    end
  else
    fallback_slug, fallback_def = ExoMol._resolve_fallback_iso(molecule, isotopologue, response)
    if isnothing(fallback_slug)
      @warn "No cached broadening data found for any other isotopologue of $molecule; skipping broadening fallback."
      return iso
    end
  end

  @info "Using broadening data from $fallback_slug"
  ExoMol._download_broad_files(molecule, fallback_slug, dataset_dir, fallback_def; force, verbose)

  broad_files = filter(f -> endswith(f, ".broad"), joinpath.(dataset_dir, readdir(dataset_dir)))
  return Isotopologue(iso.definitions, iso.states, iso.transitions, iso.partition_function, _read_broadeners(broad_files))
end
