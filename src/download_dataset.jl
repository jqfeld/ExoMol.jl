using JSON
using Downloads
using Scratch
using ProgressMeter


"""
    get_exomol_dataset(molecule, isotopologue, dataset; wn_range=nothing, force=false, verbose=false)

Download a specific ExoMol dataset and cache it in the package scratch space.

# Arguments
- `molecule`: Molecular formula (e.g. `"H2O"`).
- `isotopologue`: Isotopologue identifier as used by ExoMol (e.g. `"1H2-16O"`).
- `dataset`: Dataset label (e.g. `"POKAZATEL"`).
- `wn_range`: Wavenumber range `(wn_min, wn_max)` in cm⁻¹. When provided, only
  transition files whose range falls entirely within `[wn_min, wn_max]` are
  downloaded. Unsegmented transition files (covering the full range) are always
  included. Defaults to `nothing` (download all transition files).
- `force::Bool=false`: Re-download files even if they already exist in the local
  cache.
- `verbose::Bool=false`: Forward verbose output to `Downloads.download`.

# Returns
- `String`: Path to the local directory that contains the dataset definition and
  accompanying data files.

The returned directory contains at least the `.def.json`, `.states.bz2` and
`.trans.bz2` files required to load the dataset into Julia using
[`load_isotopologue`](@ref).

"""
function get_exomol_dataset(molecule, isotopologue, dataset;
  wn_range=nothing, force=false, verbose=false, _response=nothing)

  datasets_dir = @get_scratch!("exomol_datasets")
  dataset_dir = joinpath(datasets_dir, molecule, isotopologue, dataset)
  def_path = joinpath(dataset_dir, _data_filename(isotopologue, dataset, "def.json"))

  if !isfile(def_path) || force
    mkpath(dataset_dir)
    @info "Downloading dataset..."
    Downloads.download(_data_url(molecule, isotopologue, dataset, "def.json"), def_path; verbose)
    @info "Obtained dataset definition file."
    Downloads.download(
      _data_url(molecule, isotopologue, dataset, "states.bz2"),
      joinpath(dataset_dir, _data_filename(isotopologue, dataset, "states.bz2"));
      verbose)
    @info "Obtained states file"
  end

  pf_path = joinpath(dataset_dir, _data_filename(isotopologue, dataset, "pf"))
  if !isfile(pf_path) || force
    Downloads.download(_data_url(molecule, isotopologue, dataset, "pf"), pf_path; verbose)
    @info "Obtained partition function file"
  end

  trans_urls = _fetch_trans_urls(molecule, isotopologue, dataset; wn_range, _response)
  pending = force ? trans_urls : filter(url -> !isfile(joinpath(dataset_dir, basename(url))), trans_urls)

  if isempty(pending)
    @info "Using cached dataset."
  else
    @info "Downloading $(length(pending)) transition file(s)..."
    p = Progress(length(pending))
    for url in pending
      Downloads.download("https://www." * url, joinpath(dataset_dir, basename(url)); verbose)
      next!(p)
    end
    @info "done!"
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
    dst_file = joinpath(destination, filename)
    if !isfile(dst_file) || force
      cp(joinpath(src, filename), dst_file; force)
    end
  end
  return destination
end

_data_url(molecule, isotopologue, dataset, type) = "https://www.exomol.com/db/$(molecule)/$(isotopologue)/$(dataset)/$(isotopologue)__$(dataset).$(type)"
_data_filename(isotopologue, dataset, type) = "$(isotopologue)__$(dataset).$(type)"

function _fetch_linelist_api(molecule)
  buf = IOBuffer()
  Downloads.download("https://exomol.com/api/?molecule=$(molecule)&datatype=linelist", buf)
  JSON.parse(String(take!(buf)))
end

function _fetch_trans_urls(molecule, isotopologue, dataset; wn_range=nothing, _response=nothing)
  response = isnothing(_response) ? _fetch_linelist_api(molecule) : _response

  for (_, iso_data) in response
    !haskey(iso_data, "linelist") && continue
    !haskey(iso_data["linelist"], dataset) && continue
    files = iso_data["linelist"][dataset]["files"]
    any(f -> occursin("/$(isotopologue)/", f["url"]), files) || continue
    trans = filter(f -> endswith(f["url"], ".trans.bz2") && haskey(f, "size"), files)
    isnothing(wn_range) && return [f["url"] for f in trans]
    return [f["url"] for f in trans if _trans_in_wn_range(basename(f["url"]), isotopologue, dataset, wn_range)]
  end

  error("Dataset $(dataset) for isotopologue $(isotopologue) not found in ExoMol API")
end

function _recommended_dataset(molecule, isotopologue)
  response = _fetch_linelist_api(molecule)

  for (_, iso_data) in response
    !haskey(iso_data, "linelist") && continue
    linelist = iso_data["linelist"]
    iso_match = any(
      isa(info, Dict) && haskey(info, "files") &&
      any(f -> occursin("/$(isotopologue)/", f["url"]), info["files"])
      for (_, info) in linelist
    )
    iso_match || continue
    for (name, info) in linelist
      isa(info, Dict) && get(info, "recommended", false) && return name, response
    end
  end

  error("No recommended dataset found for $(molecule) / $(isotopologue)")
end

function _trans_in_wn_range(filename, isotopologue, dataset, wn_range)
  wn_min, wn_max = wn_range
  filename == "$(isotopologue)__$(dataset).trans.bz2" && return true
  m = match(r"__(\d+)-(\d+)\.trans\.bz2$", filename)
  isnothing(m) && return false
  return parse(Int, m[1]) >= wn_min && parse(Int, m[2]) <= wn_max
end
