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
