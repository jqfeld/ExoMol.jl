using Test
using ExoMol

@testset "Nitrogen" begin
  @test ExoMol._recommended_dataset("N2", "14N2")[1] == "WCCRMT"

  n2 = load_isotopologue("N2", "14N2")

  @testset "definitions" begin
    @test haskey(n2.definitions, "dataset")
    @test haskey(n2.definitions, "isotopologue")
    @test haskey(n2.definitions, "partition_function")
    @test haskey(n2.definitions, "broad")
    @test haskey(n2.definitions, "atoms")
    @test haskey(n2.definitions, "irreducible_representations")
    @test n2.definitions["isotopologue"]["iso_slug"] == "14N2"
    @test n2.definitions["atoms"]["element"]["N"] == 14
    @test n2.definitions["atoms"]["number_of_atoms"] == 2
  end

  @testset "states" begin
    @test length(n2.states) == 58380
    @test n2.states[1].ID       == 1
    @test n2.states[1].E        == 59266.252923
    @test n2.states[1].ElecState == "B3Pig"
    @test n2.states[1000].ID    == 1000
    @test n2.states[1000].E     == 64358.85344
    @test n2.states[58380].ID   == 58380
    @test n2.states[58380].E    == 130072.954819
    @test n2.states[58380].ElecState == "C3Piu"
  end

  @testset "transitions" begin
    @test length(n2.transitions) == 8389500
    @test n2.transitions[1].lower_id    == 27271
    @test n2.transitions[1].upper_id    ==  6853
    @test n2.transitions[1].wavenumber  == 0.000147
    @test n2.transitions[1].A           ≈ 8.0613e-26
    @test n2.transitions[7182000].lower_id   == 14821
    @test n2.transitions[7182000].upper_id   == 1080
    @test n2.transitions[7182000].wavenumber == 46379.313372
  end

  @testset "partition function" begin
    @test !isnothing(n2.partition_function)
    @test n2.partition_function(1.0) ≈ 6.0294  atol=1e-4
    @test n2.partition_function(2.0) ≈ 6.5197  atol=1e-4
    @test 6.0294 < n2.partition_function(1.5) < 6.5197
  end

  @testset "broadeners" begin
    # N2/14N2/WCCRMT's def.json advertises no broadeners at all, but the
    # server has an "air" .broad file anyway — get_exomol_dataset probes for
    # it directly (see _EXOMOL_BROADENING_PARTNERS in download_dataset.jl).
    @test collect(keys(n2.broadeners)) == ["air"]
  end
end

@testset "broad_fallback" begin
  # Exercise _load_with_broad_fallback directly against a synthetic
  # empty-broadeners Isotopologue, independent of N2/14N2 actually having
  # broadening data available (it does, via "air" — see the Nitrogen
  # "broadeners" testset above).
  dataset_dir = get_exomol_dataset("N2", "14N2", "WCCRMT")
  n2 = load_isotopologue(dataset_dir)
  empty_iso = ExoMol.Isotopologue(
    n2.definitions, n2.states, n2.transitions, n2.partition_function,
    Dict{String,Vector{BroadeningLine}}())
  response = ExoMol._fetch_linelist_api("N2")

  # auto-detect: no other N2 isotopologue with cached broadeners → warn and return empty
  n2_fb = @test_logs (:warn, r"No cached broadening") min_level=Base.CoreLogging.Warn ExoMol._load_with_broad_fallback(
    empty_iso, "N2", "14N2", dataset_dir, true, response; force=false, verbose=false)
  @test isempty(n2_fb.broadeners)

  # explicit unknown slug: not found → warn and return empty
  n2_fb2 = @test_logs (:warn, r"Could not retrieve") min_level=Base.CoreLogging.Warn ExoMol._load_with_broad_fallback(
    empty_iso, "N2", "14N2", dataset_dir, "nonexistent_iso", response; force=false, verbose=false)
  @test isempty(n2_fb2.broadeners)
end

@testset "_parse_field" begin
  @test ExoMol._parse_field(Int,     "42")  == 42
  @test ExoMol._parse_field(Float64, "3.14") ≈ 3.14
  @test ExoMol._parse_field(String,  "foo") == "foo"
  @test ExoMol._parse_field(Int,     "nan") == -2
  @test ExoMol._parse_field(Int,     "NaN") == -2
  @test isnan(ExoMol._parse_field(Float64, "nan"))
  @test isnan(ExoMol._parse_field(Float64, "NaN"))
end
