using Test
using ExoMol

# get_exomol_dataset against a fake ExoMol server on the local filesystem.
const FIXTURE = joinpath(@__DIR__, "fixtures", "XY")
file_url(path) = Sys.iswindows() ? "file:///" * replace(path, '\\' => '/') : "file://" * path

bz2(src, dest) = write(dest, transcode(ExoMol.Bzip2Compressor, read(src)))

# Lay out the fixture dataset like exomol.com/db and return the server root
# and a matching linelist API response.
function fake_server(root)
  ds_dir = mkpath(joinpath(root, "db", "XY", "1X-1Y", "TEST"))
  cp(joinpath(FIXTURE, "1X-1Y__TEST.def.json"), joinpath(ds_dir, "1X-1Y__TEST.def.json"))
  cp(joinpath(FIXTURE, "1X-1Y__TEST.pf"), joinpath(ds_dir, "1X-1Y__TEST.pf"))
  bz2(joinpath(FIXTURE, "1X-1Y__TEST.states"), joinpath(ds_dir, "1X-1Y__TEST.states.bz2"))
  cp(joinpath(FIXTURE, "1X-1Y__air.broad"), joinpath(root, "db", "XY", "1X-1Y", "1X-1Y__air.broad"))
  files = Any[]
  for seg in ("00000-00100", "00100-00200")
    name = "1X-1Y__TEST__$(seg).trans.bz2"
    bz2(joinpath(FIXTURE, "1X-1Y__TEST__$(seg).trans"), joinpath(ds_dir, name))
    push!(files, Dict("url" => file_url(joinpath(ds_dir, name)), "size" => filesize(joinpath(ds_dir, name))))
  end
  response = Dict("1X-1Y" => Dict("linelist" => Dict("TEST" => Dict("files" => files))))
  return root, response
end

# Point the package at `base` for the duration of `f`; the API always fails,
# so any unexpected API call shows up as an error.
function with_server(f, base)
  old = (ExoMol._EXOMOL_BASE[], ExoMol._EXOMOL_API[])
  ExoMol._EXOMOL_BASE[] = file_url(base)
  ExoMol._EXOMOL_API[] = file_url(joinpath(base, "no-api"))
  try
    f()
  finally
    ExoMol._EXOMOL_BASE[], ExoMol._EXOMOL_API[] = old
  end
end

@testset "wn_range filtering" begin
  f = ExoMol._trans_in_wn_range

  # Unsegmented file always passes
  @test  f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (500, 600))

  # File fully inside range
  @test  f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (250, 500))

  # Exact boundary: lower == wn_min and upper == wn_max
  @test  f("1H2-16O__BT2__00000-00100.trans.bz2", "1H2-16O", "BT2", (0, 100))

  # File partially overlaps range → included (overlap semantics)
  @test  f("1H2-16O__BT2__00900-01100.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2__00000-00250.trans.bz2", "1H2-16O", "BT2", (100, 1000))
  @test  f("1H2-16O__BT2__00500-01000.trans.bz2", "1H2-16O", "BT2", (0, 900))

  # Uncompressed files follow the same rules
  @test  f("1H2-16O__BT2.trans", "1H2-16O", "BT2", (500, 600))
  @test  f("1H2-16O__BT2__00250-00500.trans", "1H2-16O", "BT2", (0, 300))
  @test !f("1H2-16O__BT2__00250-00500.trans", "1H2-16O", "BT2", (600, 700))

  # File entirely outside range → excluded
  @test !f("1H2-16O__BT2__00000-00100.trans.bz2", "1H2-16O", "BT2", (200, 500))
  @test !f("1H2-16O__BT2__00600-01000.trans.bz2", "1H2-16O", "BT2", (100, 500))

  # Unrecognised suffix → included (can't determine its coverage from the
  # name alone, so the safe default is to include it rather than risk
  # silently dropping in-range data — see N2/WCCRMT's real "__ERJ" file,
  # which turned out to hold an entire band system omitted by this filter
  # before this behavior was fixed), and a warning is emitted so the caller
  # knows a heuristic decision was made.
  @test_logs (:warn, r"doesn't match a recognized wavenumber-range naming pattern") begin
    @test f("1H2-16O__BT2__ERJ.trans.bz2", "1H2-16O", "BT2", (0, 99999))
  end
end

@testset "_absolute_url" begin
  @test ExoMol._absolute_url("www.exomol.com/db/a.bz2") == "https://www.exomol.com/db/a.bz2"
  @test ExoMol._absolute_url("exomol.com/db/a.bz2") == "https://www.exomol.com/db/a.bz2"
  @test ExoMol._absolute_url("https://exomol.com/db/a.bz2") == "https://exomol.com/db/a.bz2"
  @test ExoMol._absolute_url("file:///tmp/a.bz2") == "file:///tmp/a.bz2"
end

@testset "_download_atomic leaves nothing on failure" begin
  mktempdir() do dir
    dest = joinpath(dir, "out")
    @test_throws Exception ExoMol._download_atomic(file_url(joinpath(dir, "missing")), dest)
    @test isempty(readdir(dir))
  end
end

@testset "get_exomol_dataset (fake server)" begin
  mktempdir() do tmp
    server, response = fake_server(joinpath(tmp, "server"))
    dest = joinpath(tmp, "data")

    with_server(server) do
      get_exomol_dataset("XY", "1X-1Y", "TEST"; dest, _response=response)
    end
    @test sort(filter(!startswith("."), readdir(dest))) == sort([
      "1X-1Y__TEST.def.json", "1X-1Y__TEST.states.bz2", "1X-1Y__TEST.pf", "1X-1Y__air.broad",
      "1X-1Y__TEST__00000-00100.trans.bz2", "1X-1Y__TEST__00100-00200.trans.bz2"])
    manifest = ExoMol.JSON.parsefile(joinpath(dest, ".exomol_manifest.json"))
    @test length(manifest["trans_files"]) == 2
    @test "self" in manifest["broad_missing"]
    @test !("air" in manifest["broad_missing"])

    iso = load_isotopologue(dest)
    @test length(iso.states) == 4
    @test length(iso.transitions) == 4

    # Missing states file is fetched again even though .def.json exists, and
    # the manifest means the API is not needed.
    rm(joinpath(dest, "1X-1Y__TEST.states.bz2"))
    with_server(server) do
      get_exomol_dataset("XY", "1X-1Y", "TEST"; dest)
    end
    @test isfile(joinpath(dest, "1X-1Y__TEST.states.bz2"))

    # Fully cached: works with the server gone entirely.
    rm(server; recursive=true)
    with_server(server) do
      @test get_exomol_dataset("XY", "1X-1Y", "TEST"; dest) == dest
      @test get_exomol_dataset("XY", "1X-1Y", "TEST"; dest, wn_range=(0, 90)) == dest
    end
  end
end

@testset "wn_range downloads only overlapping files" begin
  mktempdir() do tmp
    server, response = fake_server(joinpath(tmp, "server"))
    dest = joinpath(tmp, "data")
    with_server(server) do
      get_exomol_dataset("XY", "1X-1Y", "TEST"; dest, wn_range=(0, 90), _response=response)
    end
    @test isfile(joinpath(dest, "1X-1Y__TEST__00000-00100.trans.bz2"))
    @test !isfile(joinpath(dest, "1X-1Y__TEST__00100-00200.trans.bz2"))

    # The manifest keeps the full list, so widening the range later only
    # downloads the newly needed file.
    with_server(server) do
      get_exomol_dataset("XY", "1X-1Y", "TEST"; dest, wn_range=(0, 150))
    end
    @test isfile(joinpath(dest, "1X-1Y__TEST__00100-00200.trans.bz2"))
  end
end

@testset "load_isotopologue without states file" begin
  mktempdir() do dir
    cp(joinpath(FIXTURE, "1X-1Y__TEST.def.json"), joinpath(dir, "1X-1Y__TEST.def.json"))
    @test_throws ErrorException("No .states file found in $dir") load_isotopologue(dir)
  end
end

@testset "broad_fallback" begin
  mol = "XYFALLBACKTEST"
  mol_dir = joinpath(ExoMol.Scratch.get_scratch!(ExoMol, "exomol_datasets"), mol)
  try
    # Cached isotopologues 1X-2Y and 1X-3Y of a test molecule, each with an
    # "air" broadening file.
    for slug in ("1X-2Y", "1X-3Y")
      d = mkpath(joinpath(mol_dir, slug, "TEST"))
      cp(joinpath(FIXTURE, "1X-1Y__air.broad"), joinpath(d, "$(slug)__air.broad"))
    end
    url(slug) = Dict("url" => "www.exomol.com/db/$mol/$slug/TEST/$(slug)__TEST.trans.bz2")
    # Ordered, like the parsed API response
    response(slugs...) = [s => Dict("linelist" => Dict("TEST" => Dict("files" => [url(s)]))) for s in slugs]

    base = load_isotopologue(FIXTURE)
    empty_iso = ExoMol.Isotopologue(base.definitions, base.states, base.transitions,
      base.partition_function, Dict{String,Vector{BroadeningLine}}())
    fb(arg, resp; force=false) = ExoMol._load_with_broad_fallback(empty_iso, mol, "1X-1Y", arg, resp; force, verbose=false)

    # Auto: first cached isotopologue in API order
    iso = @test_logs (:info, r"borrowed from 1X-2Y") fb(true, response("1X-1Y", "1X-2Y", "1X-3Y"))
    @test collect(keys(iso.broadeners)) == ["air"]
    @test_logs (:info, r"borrowed from 1X-3Y") fb(true, response("1X-1Y", "1X-3Y", "1X-2Y"))
    # Cached but not listed by the API: still found
    @test_logs (:info, r"borrowed from 1X-2Y") fb(true, response("1X-1Y"))

    # Explicit cached slug
    @test_logs (:info, r"borrowed from 1X-3Y") fb("1X-3Y", response("1X-1Y"))

    # Explicit slug not cached yet: downloaded into its own cache directory
    mktempdir() do tmp
      server = joinpath(tmp, "server")
      d = mkpath(joinpath(server, "db", mol, "1X-4Y", "TEST"))
      cp(joinpath(FIXTURE, "1X-1Y__TEST.def.json"), joinpath(d, "1X-4Y__TEST.def.json"))
      cp(joinpath(FIXTURE, "1X-1Y__air.broad"), joinpath(server, "db", mol, "1X-4Y", "1X-4Y__air.broad"))
      iso4 = with_server(server) do
        @test_logs (:info, r"broadening file") (:info, r"borrowed from 1X-4Y") fb("1X-4Y", response("1X-1Y", "1X-4Y"))
      end
      @test collect(keys(iso4.broadeners)) == ["air"]
      @test isfile(joinpath(mol_dir, "1X-4Y", "TEST", "1X-4Y__air.broad"))
      @test isfile(joinpath(mol_dir, "1X-4Y", "TEST", "1X-4Y__TEST.def.json"))

      # force=true refreshes the cached source files, explicitly and in auto mode
      write(joinpath(server, "db", mol, "1X-4Y", "1X-4Y__air.broad"), "a0 0.0123 0.400\n")
      iso4b = with_server(server) do
        fb("1X-4Y", response("1X-1Y", "1X-4Y"); force=true)
      end
      @test only(iso4b.broadeners["air"]).gamma_L == 0.0123
      write(joinpath(server, "db", mol, "1X-4Y", "1X-4Y__air.broad"), "a0 0.0456 0.400\n")
      iso4c = with_server(server) do
        fb(true, response("1X-1Y", "1X-4Y"); force=true)
      end
      @test only(iso4c.broadeners["air"]).gamma_L == 0.0456
    end

    # Unknown slug: warning, broadeners stay empty
    iso_none = @test_logs (:warn, r"Could not retrieve") fb("1X-9Y", response("1X-1Y"))
    @test isempty(iso_none.broadeners)
  finally
    rm(mol_dir; recursive=true, force=true)
  end
  # Nothing cached for the molecule at all
  iso = @test_logs (:warn, r"No cached broadening") ExoMol._load_with_broad_fallback(
    load_isotopologue(FIXTURE), mol, "1X-1Y", true, Dict(); force=false, verbose=false)
end

@testset "borrowed broadening is not stored with the dataset" begin
  mol = "XYFALLBACKTEST2"
  mol_dir = joinpath(ExoMol.Scratch.get_scratch!(ExoMol, "exomol_datasets"), mol)
  try
    d = mkpath(joinpath(mol_dir, "1X-2Y", "TEST"))
    cp(joinpath(FIXTURE, "1X-1Y__air.broad"), joinpath(d, "1X-2Y__self.broad"))
    mktempdir() do dir
      for f in readdir(FIXTURE)
        endswith(f, ".broad") || cp(joinpath(FIXTURE, f), joinpath(dir, f))
      end
      before = readdir(dir)
      iso = load_isotopologue(dir)
      @test isempty(iso.broadeners)
      iso_fb = ExoMol._load_with_broad_fallback(iso, mol, "1X-1Y", true, Dict(); force=false, verbose=false)
      @test collect(keys(iso_fb.broadeners)) == ["self"]
      @test readdir(dir) == before
      @test isempty(load_isotopologue(dir).broadeners)
    end
  finally
    rm(mol_dir; recursive=true, force=true)
  end
end
