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

@testset "read_trans_file column layouts" begin
  mktempdir() do dir
    f = joinpath(dir, "x.trans")
    # Narrow IDs, wide padding, a tab, CRLF line ending and a blank line
    write(f, "      7      3   1.0e-02    50.0\n\n12345678901234 2\t2.5e-03 30.0\r\n")
    @test read_trans_file(f) == [Transition(7, 3, 1.0e-2, 50.0),
                                 Transition(12345678901234, 2, 2.5e-3, 30.0)]
    # Wavenumber column absent
    write(f, "           2            1 1.0000e-02\n")
    @test read_trans_file(f) == [Transition(2, 1, 1.0e-2, 0.0)]
    # Too few columns
    write(f, "           2            1\n")
    @test_throws ErrorException read_trans_file(f)
  end
end

@testset "read_state_file promotes integer column mid-file" begin
  mktempdir() do dir
    def = Dict("dataset" => Dict("states" => Dict("states_file_fields" => [
      Dict("name" => "ID", "ffmt" => "I12"), Dict("name" => "E", "ffmt" => "F12.6"),
      Dict("name" => "Sigma", "ffmt" => "I7")])))
    f = joinpath(dir, "x.states")
    write(f, "1 0.0 NaN\r\n2 1.0 1\n3 2.0 0.5\n4 3.0 nan\n")
    states = read_state_file(f, def)
    @test eltype(states) == @NamedTuple{ID::Int, E::Float64, Sigma::Float64}
    @test isnan(states[1].Sigma)      # "nan" before promotion → NaN, not -2.0
    @test states[2].Sigma === 1.0
    @test states[3].Sigma === 0.5
    @test isnan(states[4].Sigma)
  end
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

@testset "wavenumber recovery is per file" begin
  mktempdir() do dir
    for f in readdir(FIXTURE)
      cp(joinpath(FIXTURE, f), joinpath(dir, f))
    end
    # Only the second segment lacks the wavenumber column
    f = joinpath(dir, "1X-1Y__TEST__00100-00200.trans")
    lines = [join(split(l)[1:3], ' ') for l in eachline(f)]
    write(f, join(lines, '\n') * '\n')
    iso = load_isotopologue(dir)
    @test Set(t.wavenumber for t in iso.transitions) == Set([50.0, 30.0, 120.0, 100.0])

    # A transition referring to an unknown state is a clear error
    write(f, "          99            1 1.0e-02\n")
    @test_throws ErrorException("State ID 99 referenced in a transition file is not in the states file") load_isotopologue(dir)
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
