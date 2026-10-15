using JSON
using Downloads
using Scratch


function _human_bytes(n)
  n < 1_000         && return "$(n) B"
  n < 1_000_000     && return "$(round(n/1_000,         digits=1)) kB"
  n < 1_000_000_000 && return "$(round(n/1_000_000,     digits=1)) MB"
  return "$(round(n/1_000_000_000, digits=1)) GB"
end

# Base URLs of the ExoMol server and API. Refs so tests can point them at a
# local fake server.
const _EXOMOL_BASE = Ref("https://www.exomol.com")
const _EXOMOL_API = Ref("https://exomol.com/api/")

_db_url(path) = "$(_EXOMOL_BASE[])/db/$(path)"

# Timeout (s) for API requests, so a hanging network falls back to the cached
# response instead of blocking.
const _API_TIMEOUT = Ref(30.0)

# Offline mode: the `offline` keyword or the EXOMOL_OFFLINE environment variable.
_is_offline(offline) = offline || lowercase(get(ENV, "EXOMOL_OFFLINE", "false")) in ("true", "1")

# Raised when offline use needs data that is not in the local cache.
struct ExoMolCacheError <: Exception
  msg::String
end
Base.showerror(io::IO, e::ExoMolCacheError) = print(io, "ExoMolCacheError: ", e.msg)

# File URLs from the ExoMol API usually lack a scheme
# ("www.exomol.com/db/..."); accept full URLs as well.
function _absolute_url(url)
  occursin(r"^[a-z]+://", url) && return url
  url = lstrip(url, '/')
  startswith(url, "www.") && return "https://" * url
  return "https://www." * url
end

# Download to a temporary name and rename on success, so an interrupted
# download never leaves a truncated file that later looks cached.
function _download_atomic(url, dest; kwargs...)
  tmp = dest * ".part"
  try
    Downloads.download(url, tmp; kwargs...)
  catch
    rm(tmp; force=true)
    rethrow()
  end
  mv(tmp, dest; force=true)
end

function _download_with_progress(url, dest; desc="", verbose=false)
  # A redrawn progress bar only makes sense on a terminal; in CI logs the
  # escape codes and per-chunk lines just flood the output.
  stderr isa Base.TTY || return _download_atomic(url, dest; verbose)
  shown = Ref(false)
  last_draw = Ref(0.0)
  _download_atomic(url, dest; verbose,
    progress = (total, now) -> begin
      done = total > 0 && now >= total
      t = time()
      (!done && t - last_draw[] < 0.1) && return
      last_draw[] = t
      shown[] = true
      cols = displaysize(stderr)[2]
      if total > 0
        frac = clamp(now / total, 0.0, 1.0)
        bar_width = max(10, cols - length(desc) - 30)
        filled = round(Int, frac * bar_width)
        bar = "█"^filled * "░"^(bar_width - filled)
        pct = round(Int, 100 * frac)
        print(stderr, "\e[2K\r$(desc) [$(bar)] $(pct)%  $(_human_bytes(now)) / $(_human_bytes(total))")
      else
        print(stderr, "\e[2K\r$(desc)  $(_human_bytes(now)) downloaded…")
      end
      flush(stderr)
    end)
  shown[] && println(stderr)
end


"""
    get_exomol_dataset(molecule, isotopologue, dataset; dest=nothing, wn_range=nothing, force=false, verbose=false)

Download a specific ExoMol dataset and store it locally.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: Isotopologue identifier as used by ExoMol (e.g. `"1H2-16O"`).
- `dataset`: Dataset label (e.g. `"POKAZATEL"`).
- `dest::Union{AbstractString,Nothing}=nothing`: Directory to download files into.
  When `nothing` (default) files are stored in the package scratch space
  (`~/.julia/scratchspaces/…/exomol_datasets/molecule/isotopologue/dataset/`).
  When a path is given, files are written directly into that directory (created
  if it does not exist) with no additional sub-directories appended. Use this to
  avoid keeping a second copy of a large dataset in the scratch space.
- `wn_range`: Wavenumber range `(wn_min, wn_max)` in cm⁻¹. When provided, only
  transition files that overlap `[wn_min, wn_max]` are downloaded. Unsegmented
  transition files (those without a wavenumber range in their filename) are always
  included. Defaults to `nothing` (download all transition files).
- `force::Bool=false`: Re-download files even if they already exist in the local
  cache.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.
- `offline::Bool=false`: Never access the network; use only cached files and
  raise an `ExoMolCacheError` if a needed file is missing. Also enabled by the
  environment variable `EXOMOL_OFFLINE=true`.

Once all requested files are present, no network access is needed: the list of
transition files and the broadening partners missing on the server are
remembered in a `.exomol_manifest.json` file in the dataset directory.
`force=true` refreshes it.

# Returns
- `String`: Path to the directory containing the downloaded files
  (`.def.json`, `.states.bz2`, `.pf`, `.broad`, and `.trans.bz2` files).
  This path can be passed directly to [`load_isotopologue`](@ref).
"""
function get_exomol_dataset(molecule, isotopologue, dataset;
  dest=nothing, wn_range=nothing, force=false, verbose=false, offline=false, _response=nothing)

  offline = _is_offline(offline)
  offline && force && throw(ArgumentError("force=true needs network access; it cannot be combined with offline mode"))
  if isnothing(dest)
    datasets_dir = @get_scratch!("exomol_datasets")
    dataset_dir = joinpath(datasets_dir, molecule, isotopologue, dataset)
  else
    dataset_dir = dest
  end
  mkpath(dataset_dir)
  def_path = joinpath(dataset_dir, _data_filename(isotopologue, dataset, "def.json"))
  states_path = joinpath(dataset_dir, _data_filename(isotopologue, dataset, "states.bz2"))
  pf_path = joinpath(dataset_dir, _data_filename(isotopologue, dataset, "pf"))

  if offline
    missing_files = filter(!isfile, [def_path, states_path, pf_path])
    isempty(missing_files) || throw(ExoMolCacheError(
      "offline mode: $molecule/$isotopologue/$dataset is not fully cached; missing " *
      join(basename.(missing_files), ", ")))
  end

  # Each file is checked on its own: a failed states download must not be
  # masked by an already present .def.json.
  if !isfile(def_path) || force
    @info "Downloading $molecule/$isotopologue/$dataset..."
    _download_atomic(_data_url(molecule, isotopologue, dataset, "def.json"), def_path; verbose)
  end
  if !isfile(states_path) || force
    _download_with_progress(_data_url(molecule, isotopologue, dataset, "states.bz2"), states_path;
      desc="  States:", verbose)
  end
  if !isfile(pf_path) || force
    _download_atomic(_data_url(molecule, isotopologue, dataset, "pf"), pf_path; verbose)
    @info "Obtained partition function file"
  end

  # The manifest remembers the transition file list and the broadening
  # partners the server has no file for, so a fully cached dataset loads
  # without touching the network.
  manifest_path = joinpath(dataset_dir, _MANIFEST_FILENAME)
  manifest = (!force && isfile(manifest_path)) ? JSON.parsefile(manifest_path) : Dict{String,Any}()

  def = JSON.parsefile(def_path)
  broad_missing = offline ? get(manifest, "broad_missing", String[]) :
    _download_broad_files(molecule, isotopologue, dataset_dir, def;
      force, verbose, skip=get(manifest, "broad_missing", String[]))

  all_trans = if haskey(manifest, "trans_files")
    [(url=f["url"], size=get(f, "size", nothing)) for f in manifest["trans_files"]]
  else
    response = isnothing(_response) ? _fetch_linelist_api(molecule; offline) : _response
    _trans_files_from_response(response, isotopologue, dataset)
  end
  _write_manifest(manifest_path, all_trans, broad_missing)

  trans_files = isnothing(wn_range) ? all_trans :
    filter(t -> _trans_in_wn_range(basename(t.url), isotopologue, dataset, wn_range), all_trans)
  pending = force ? trans_files : filter(t -> !isfile(joinpath(dataset_dir, basename(t.url))), trans_files)
  offline && !isempty(pending) && throw(ExoMolCacheError(
    "offline mode: $(length(pending)) transition file(s) of $molecule/$isotopologue/$dataset " *
    "are not cached: " * join(basename.(t.url for t in pending), ", ")))

  if isempty(pending)
    @info "Using cached dataset."
  else
    n = length(pending)
    known = sum(t.size for t in pending if !isnothing(t.size); init=0)
    size_str = known > 0 ? " ($(_human_bytes(known))$(any(isnothing(t.size) for t in pending) ? "+" : "") total)" : ""
    @info "Downloading $n transition file(s)$size_str..."
    for (i, t) in enumerate(pending)
      fname = basename(t.url)
      _download_with_progress(_absolute_url(t.url), joinpath(dataset_dir, fname);
        desc="  [$i/$n] $fname:", verbose)
    end
  end

  return dataset_dir
end


"""
    save_dataset(destination, molecule, isotopologue, dataset; force=false)

Copy a cached ExoMol dataset from the scratch space to a directory of choice.

The dataset must already be present in the local cache (i.e. `get_exomol_dataset`
must have been called first). Only the files currently in the cache are copied,
so if the dataset was downloaded with a `wn_range` filter, only those transition
files will appear at the destination.

The destination directory layout is identical to what [`load_isotopologue`](@ref)
expects, so the saved path can be passed directly to it:

```julia
iso = load_isotopologue(save_dataset("/data/exomol", "H2O", "1H2-16O", "POKAZATEL"))
```

# Arguments
- `destination::AbstractString`: Directory to write files into. Created if it
  does not exist.
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: ExoMol isotopologue identifier (e.g. `"1H2-16O"`).
- `dataset`: Dataset label (e.g. `"POKAZATEL"`).
- `force::Bool=false`: Overwrite files that already exist at the destination.

# Returns
- `String`: `destination`, for use in pipelines.
"""
function save_dataset(destination, molecule, isotopologue, dataset; force=false)
  src = joinpath(@get_scratch!("exomol_datasets"), molecule, isotopologue, dataset)
  isfile(joinpath(src, _data_filename(isotopologue, dataset, "def.json"))) ||
    error("Dataset not in cache — run get_exomol_dataset(\"$molecule\", \"$isotopologue\", \"$dataset\") first.")

  mkpath(destination)
  for filename in readdir(src)
    endswith(filename, ".part") && continue
    dst_file = joinpath(destination, filename)
    if !isfile(dst_file) || force
      cp(joinpath(src, filename), dst_file; force)
    end
  end
  return destination
end

_data_url(molecule, isotopologue, dataset, type) = _db_url("$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).$(type)")
_data_filename(isotopologue, dataset, type) = "$(isotopologue)__$(dataset).$(type)"

const _MANIFEST_FILENAME = ".exomol_manifest.json"

function _write_manifest(path, trans_files, broad_missing)
  manifest = Dict(
    "trans_files" => [Dict("url" => t.url, "size" => t.size) for t in trans_files],
    "broad_missing" => sort!(collect(broad_missing)),
  )
  tmp = path * ".part"
  write(tmp, JSON.json(manifest))
  mv(tmp, path; force=true)
end

_api_cache_path(molecule) = joinpath(@get_scratch!("exomol_api"), "$(molecule).linelist.json")

# Query the ExoMol linelist API and cache the response. If the API cannot be
# reached (or in offline mode), the cached response is used instead.
function _fetch_linelist_api(molecule; offline=false)
  cache = _api_cache_path(molecule)
  if !_is_offline(offline)
    try
      buf = IOBuffer()
      Downloads.download("$(_EXOMOL_API[])?molecule=$(molecule)&datatype=linelist", buf;
        timeout=_API_TIMEOUT[])
      text = String(take!(buf))
      response = JSON.parse(text)
      write(cache * ".part", text)
      mv(cache * ".part", cache; force=true)
      return response
    catch e
      e isa Downloads.RequestError || rethrow()
      isfile(cache) || throw(ExoMolCacheError(
        "the ExoMol API is unreachable ($(e.message)) and no cached response for $molecule " *
        "exists; run once with network access first"))
      days = round(Int, (time() - mtime(cache)) / 86400)
      @warn "ExoMol API unreachable; using cached response for $molecule from $days day(s) ago" cache
    end
  elseif !isfile(cache)
    throw(ExoMolCacheError("offline mode: no cached ExoMol API response for $molecule; " *
      "run once with network access first"))
  end
  return JSON.parsefile(cache)
end

function _trans_files_from_response(response, isotopologue, dataset)
  for (_, iso_data) in response
    !haskey(iso_data, "linelist") && continue
    !haskey(iso_data["linelist"], dataset) && continue
    files = iso_data["linelist"][dataset]["files"]
    any(f -> occursin("/$(isotopologue)/", f["url"]), files) || continue
    trans = filter(f -> endswith(f["url"], ".trans.bz2"), files)
    return [(url=f["url"], size=get(f, "size", nothing)) for f in trans]
  end

  error("Dataset $(dataset) for isotopologue $(isotopologue) not found in ExoMol API")
end

function _fetch_trans_urls(molecule, isotopologue, dataset; wn_range=nothing, _response=nothing)
  response = isnothing(_response) ? _fetch_linelist_api(molecule) : _response
  trans = _trans_files_from_response(response, isotopologue, dataset)
  isnothing(wn_range) && return trans
  return filter(t -> _trans_in_wn_range(basename(t.url), isotopologue, dataset, wn_range), trans)
end

function _recommended_dataset(molecule, isotopologue; offline=false)
  response = _fetch_linelist_api(molecule; offline)

  for (_, iso_data) in response
    !haskey(iso_data, "linelist") && continue
    linelist = iso_data["linelist"]
    iso_match = any(
      isa(info, AbstractDict) && haskey(info, "files") &&
      any(f -> occursin("/$(isotopologue)/", f["url"]), info["files"])
      for (_, info) in linelist
    )
    iso_match || continue
    for (name, info) in linelist
      isa(info, AbstractDict) && get(info, "recommended", false) && return name, response
    end
  end

  error("No recommended dataset found for $(molecule) / $(isotopologue)")
end

# Datasets of an isotopologue that load without network access: .def.json,
# .states.bz2 and manifest present (in the scratch cache, or in `dest`).
function _cached_datasets(molecule, isotopologue; dest=nothing)
  dirs = if isnothing(dest)
    iso_dir = joinpath(@get_scratch!("exomol_datasets"), molecule, isotopologue)
    isdir(iso_dir) ? filter(isdir, readdir(iso_dir; join=true)) : String[]
  else
    isdir(dest) ? [dest] : String[]
  end
  prefix = "$(isotopologue)__"
  names = String[]
  for dir in dirs, f in readdir(dir)
    (startswith(f, prefix) && endswith(f, ".def.json")) || continue
    ds = chop(f; head=length(prefix), tail=length(".def.json"))
    isfile(joinpath(dir, _data_filename(isotopologue, ds, "states.bz2"))) &&
      isfile(joinpath(dir, _MANIFEST_FILENAME)) && push!(names, ds)
  end
  return unique!(names)
end

# Recommended dataset of an isotopologue and the API response it came from.
# Without any API response (live or cached), fall back to the only cached
# dataset of the isotopologue, if there is exactly one.
function _resolve_recommended(molecule, isotopologue; dest=nothing, offline=false)
  try
    dataset, response = _recommended_dataset(molecule, isotopologue; offline)
    @info "Using recommended dataset: $dataset"
    return dataset, response
  catch e
    e isa ExoMolCacheError || rethrow()
    cached = _cached_datasets(molecule, isotopologue; dest)
    isempty(cached) && throw(ExoMolCacheError(e.msg * "; no cached dataset of $isotopologue found either"))
    length(cached) > 1 && throw(ExoMolCacheError(e.msg * "; several cached datasets of " *
      "$isotopologue ($(join(cached, ", "))), pass the dataset name explicitly"))
    @warn "Cannot determine the recommended dataset; using the only cached dataset of $isotopologue: $(only(cached))"
    return only(cached), nothing
  end
end

# API response for the broadening fallback, which only needs it to order and
# locate isotopologues: an empty response if none is available.
function _response_for_fallback(molecule, response; offline=false)
  isnothing(response) || return response
  try
    return _fetch_linelist_api(molecule; offline)
  catch e
    e isa ExoMolCacheError || rethrow()
    return Dict{String,Any}()
  end
end

# Common ExoMol broadening-partner codes (ExoMol 2024 release paper, Table 2).
# .def.json only advertises a subset of the partners that actually have a
# .broad file on the server (e.g. H2O/1H2-16O has an "air" file that no
# .def.json on exomol.com mentions). RADIS works around this by probing every
# known partner code directly; we do the same below.
const _EXOMOL_BROADENING_PARTNERS = [
  "air", "self", "H2", "He", "Ar", "CH4", "CO", "CO2", "H2O", "N2", "NH3", "NO", "O2", "CS",
]

# Returns the probed partners the server has no file for (including those in
# `skip`, which are not probed again).
function _download_broad_files(molecule, iso_slug, dest_dir, def; force=false, verbose=false, skip=())
  advertised = Set{String}()
  for (_, broad_info) in get(def, "broad", Dict())
    isa(broad_info, AbstractDict) || continue
    filename = broad_info["filename"]
    push!(advertised, filename)
    broad_path = joinpath(dest_dir, filename)
    if !isfile(broad_path) || force
      _download_atomic(_db_url("$(molecule)/$(iso_slug)/$(filename)"), broad_path; verbose)
      @info "Obtained broadening file: $filename"
    end
  end

  missing_partners = String[]
  for partner in _EXOMOL_BROADENING_PARTNERS
    filename = "$(iso_slug)__$(partner).broad"
    filename in advertised && continue
    broad_path = joinpath(dest_dir, filename)
    (!force && isfile(broad_path)) && continue
    if !force && partner in skip
      push!(missing_partners, partner)
      continue
    end
    try
      _download_atomic(_db_url("$(molecule)/$(iso_slug)/$(filename)"), broad_path; verbose)
      @info "Obtained broadening file: $filename"
    catch e
      e isa Downloads.RequestError || rethrow()
      # Only remember genuine "not found"; a transient error is retried next time.
      _is_not_found(e) && push!(missing_partners, partner)
    end
  end
  return missing_partners
end

# HTTP 404, or curl's "couldn't read file" for file:// URLs.
_is_not_found(e::Downloads.RequestError) = e.response.status == 404 || e.code == 37

function _find_cached_def(molecule, iso_slug)
  datasets_dir = @get_scratch!("exomol_datasets")
  iso_dir = joinpath(datasets_dir, molecule, iso_slug)
  isdir(iso_dir) || return nothing
  for ds_name in readdir(iso_dir)
    def_path = joinpath(iso_dir, ds_name, "$(iso_slug)__$(ds_name).def.json")
    isfile(def_path) && return JSON.parsefile(def_path)
  end
  return nothing
end

function _fetch_def_for_iso(molecule, iso_slug, response)
  cached = _find_cached_def(molecule, iso_slug)
  isnothing(cached) || return cached
  best_ds = nothing
  for (_, iso_data) in response
    isa(iso_data, AbstractDict) && haskey(iso_data, "linelist") || continue
    for (ds_name, ds_info) in iso_data["linelist"]
      isa(ds_info, AbstractDict) || continue
      any(f -> isa(f, AbstractDict) && occursin("/$(iso_slug)/", get(f, "url", "")), get(ds_info, "files", [])) || continue
      if isnothing(best_ds) || get(ds_info, "recommended", false)
        best_ds = ds_name
      end
    end
  end
  isnothing(best_ds) && return nothing
  buf = IOBuffer()
  try
    Downloads.download(_data_url(molecule, iso_slug, best_ds, "def.json"), buf)
  catch e
    e isa Downloads.RequestError || rethrow()
    return nothing
  end
  return JSON.parse(String(take!(buf)))
end

# Isotopologue slugs of a molecule in the order the ExoMol API lists them.
function _iso_slugs(response)
  slugs = String[]
  for (_, iso_data) in response
    isa(iso_data, AbstractDict) && haskey(iso_data, "linelist") || continue
    for (_, ds_info) in iso_data["linelist"]
      isa(ds_info, AbstractDict) || continue
      for f in get(ds_info, "files", [])
        isa(f, AbstractDict) || continue
        m = match(r"/db/[^/]+/([^/]+)/", get(f, "url", ""))
        isnothing(m) || m[1] in slugs || push!(slugs, m[1])
      end
    end
  end
  return slugs
end

# .broad files of an isotopologue in any of its cached datasets, keyed by
# broadening partner.
function _cached_broad_files(molecule, iso_slug)
  files = Dict{String,String}()
  iso_dir = joinpath(@get_scratch!("exomol_datasets"), molecule, iso_slug)
  isdir(iso_dir) || return files
  for ds_dir in readdir(iso_dir; join=true)
    isdir(ds_dir) || continue
    for f in readdir(ds_dir; join=true)
      m = match(r"^.+__(.+)\.broad$", basename(f))
      isnothing(m) || get!(files, m[1], f)
    end
  end
  return files
end

# First other isotopologue with cached broadening files: those the API lists,
# in its order (main isotopologue first), then any other cached ones.
function _resolve_fallback_broad(molecule, current_iso, response)
  mol_dir = joinpath(@get_scratch!("exomol_datasets"), molecule)
  cached = isdir(mol_dir) ? sort!(filter(d -> isdir(joinpath(mol_dir, d)), readdir(mol_dir))) : String[]
  for slug in unique!(vcat(_iso_slugs(response), cached))
    slug == current_iso && continue
    files = _cached_broad_files(molecule, slug)
    isempty(files) || return slug, files
  end
  return nothing, Dict{String,String}()
end

# Download the broadening files of `iso_slug` into its own cache directory
# (next to its .def.json), never into another dataset's folder.
function _fetch_broad_files_for_iso(molecule, iso_slug, response; force=false, verbose=false, offline=false)
  offline && return Dict{String,String}()
  def = _fetch_def_for_iso(molecule, iso_slug, response)
  isnothing(def) && return Dict{String,String}()
  ds_name = def["dataset"]["name"]
  ds_dir = mkpath(joinpath(@get_scratch!("exomol_datasets"), molecule, iso_slug, ds_name))
  def_path = joinpath(ds_dir, _data_filename(iso_slug, ds_name, "def.json"))
  isfile(def_path) || write(def_path, JSON.json(def))
  _download_broad_files(molecule, iso_slug, ds_dir, def; force, verbose)
  return _cached_broad_files(molecule, iso_slug)
end

function _trans_in_wn_range(filename, isotopologue, dataset, wn_range)
  wn_min, wn_max = wn_range
  replace(filename, r"\.bz2$" => "") == "$(isotopologue)__$(dataset).trans" && return true
  m = match(r"__(\d+)-(\d+)\.trans(\.bz2)?$", filename)
  if isnothing(m)
    @warn "Transition file '$filename' doesn't match a recognized wavenumber-range naming pattern; including it rather than risk silently dropping in-range data. Pass wn_range=nothing (or check the file directly) if you want to confirm its actual coverage."
    return true
  end
  return parse(Int, m[1]) < wn_max && parse(Int, m[2]) > wn_min
end
