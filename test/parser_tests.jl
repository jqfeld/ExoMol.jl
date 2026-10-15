using Test
using ExoMol

# Offline tests against the tiny synthetic dataset in fixtures/XY.
const FIXTURE = joinpath(@__DIR__, "fixtures", "XY")
fixture(name) = joinpath(FIXTURE, "1X-1Y__TEST.$name")

@testset "read_state_file" begin
  states = read_state_file(fixture("states"))
  @test length(states) == 4
  @test states[1].ID == 1
  @test states[2].E == 50.0
  @test states[3].gtot == 5
  @test states[3].v == -2            # "NaN" in an integer column → sentinel
  @test states[3].State == "A"
  # Integer-declared column holding half-integers is promoted to Float64
  @test states[1].Sigma === 0.5
  @test states[4].Sigma === -0.5
end

@testset "read_state_file (bz2)" begin
  mktempdir() do dir
    cp(fixture("def.json"), joinpath(dir, "1X-1Y__TEST.def.json"))
    raw = read(fixture("states"))
    write(joinpath(dir, "1X-1Y__TEST.states.bz2"), transcode(ExoMol.Bzip2Compressor, raw))
    @test read_state_file(joinpath(dir, "1X-1Y__TEST.states.bz2")) ==
          read_state_file(fixture("states"))
  end
end

@testset "read_trans_file" begin
  t = read_trans_file(joinpath(FIXTURE, "1X-1Y__TEST__00000-00100.trans"))
  @test length(t) == 2
  @test t[1] == Transition(2, 1, 1.0e-2, 50.0)
  @test t[2] == Transition(4, 3, 2.5e-3, 30.0)
end

@testset "read_pf_file" begin
  pf = read_pf_file(fixture("pf"))
  @test pf(1.0) ≈ 1.0
  @test pf(100.0) ≈ 20.0
  @test pf(5.5) ≈ 1.75
end

@testset "read_broad_file" begin
  b = read_broad_file(joinpath(FIXTURE, "1X-1Y__air.broad"))
  @test length(b) == 3                # blank line skipped
  @test b[1].code == "a0"
  @test b[1].gamma_L == 0.07
  @test isnan(b[1].q1) && isnan(b[1].q2)
  @test b[2].q1 == 0 && isnan(b[2].q2)
  @test b[3].q1 == 1 && b[3].q2 == 2
end

@testset "load_isotopologue(folder)" begin
  iso = load_isotopologue(FIXTURE)
  @test length(iso.states) == 4
  @test length(iso.transitions) == 4
  @test Set(t.wavenumber for t in iso.transitions) == Set([50.0, 30.0, 120.0, 100.0])
  @test collect(keys(iso.broadeners)) == ["air"]
  @test molar_mass(iso) == 2.016
  @test iso.partition_function(10.0) ≈ 2.5
  @test sprint(show, iso) == "Isotopologue(1X-1Y/TEST, 4 states, 4 transitions)"

  # Uncompressed segmented .trans files are not yet recognised by the
  # wavenumber-range filter, so every file is still loaded.
  iso_lo = load_isotopologue(FIXTURE; wn_range=(0, 90))
  @test_broken sort([t.wavenumber for t in iso_lo.transitions]) == [30.0, 50.0]
end

@testset "load_isotopologue recovers missing wavenumbers" begin
  mktempdir() do dir
    for f in readdir(FIXTURE)
      endswith(f, ".trans") && continue
      cp(joinpath(FIXTURE, f), joinpath(dir, f))
    end
    # Same transitions, but without the wavenumber column
    for f in filter(endswith(".trans"), readdir(FIXTURE))
      open(joinpath(dir, f), "w") do io
        for l in eachline(joinpath(FIXTURE, f))
          println(io, l[1:25], " ", split(l)[3])
        end
      end
    end
    iso = @test_logs (:info, r"no wavenumber column") load_isotopologue(dir)
    @test Set(t.wavenumber for t in iso.transitions) == Set([50.0, 30.0, 120.0, 100.0])
  end
end

@testset "download progress is silent off-terminal" begin
  mktempdir() do dir
    src = fixture("pf")
    url = Sys.iswindows() ? "file:///" * replace(abspath(src), '\\' => '/') : "file://" * abspath(src)
    dest = joinpath(dir, "out.pf")
    log = joinpath(dir, "stderr.txt")
    open(log, "w") do io
      redirect_stderr(io) do
        ExoMol._download_with_progress(url, dest; desc="test:")
      end
    end
    @test read(dest) == read(src)
    @test isempty(read(log, String))
  end
end
