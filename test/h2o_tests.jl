using Test
using ExoMol

@testset "H2O POKAZATEL" begin

  # wn_range above the dataset maximum (41200 cm⁻¹) selects no trans files while
  # still downloading def, states, pf, and all .broad files — total ~7 MB.
  h2o = load_isotopologue("H2O", "1H2-16O", "POKAZATEL"; wn_range=(41200, 42000))

  @testset "definitions" begin
    @test haskey(h2o.definitions, "dataset")
    @test haskey(h2o.definitions, "isotopologue")
    @test haskey(h2o.definitions, "broad")
    @test h2o.definitions["isotopologue"]["iso_slug"] == "1H2-16O"
    @test h2o.definitions["dataset"]["name"] == "POKAZATEL"
    @test h2o.definitions["dataset"]["num_pressure_broadeners"] == 4
  end

  @testset "states" begin
    @test length(h2o.states) == 810269

    @test h2o.states[1].ID   == 1
    @test h2o.states[1].E    == 0.0
    @test h2o.states[1].gtot == 1
    @test h2o.states[1].J    == 0

    @test h2o.states[810269].ID == 810269
    @test h2o.states[810269].E  ≈ 45000.633993

    # States where rotational QNs are not applicable use "nan" in file → sentinel -2
    @test getfield(h2o.states[23], Symbol("Herzberg:Ka")) == -2
    @test getfield(h2o.states[23], Symbol("Herzberg:Kc")) == -2
  end

  @testset "transitions" begin
    # No segments overlap wn_range=(41200, 42000); last segment ends at 41200
    @test isempty(h2o.transitions)
  end

  @testset "partition function" begin
    @test !isnothing(h2o.partition_function)
    @test h2o.partition_function(296.0)  ≈ 174.5813  atol=1e-3
    @test h2o.partition_function(1000.0) ≈ 1218.2729 atol=1e-3
    @test h2o.partition_function(296.0) < h2o.partition_function(1000.0)
  end

  @testset "broadeners" begin
    # def.json lists H2 and He broadeners with filenames; CO2/H2O entries counted
    # in num_pressure_broadeners refer to recipe variants, not separate files.
    @test length(h2o.broadeners) == 2
    @test haskey(h2o.broadeners, "H2")
    @test haskey(h2o.broadeners, "He")

    h2 = h2o.broadeners["H2"]
    @test length(h2)  == 151
    @test eltype(h2)  == BroadeningLine
    @test h2[1].code    == "a1"
    @test h2[1].gamma_L ≈ 0.0916
    @test h2[1].n_air   ≈ 0.790
    @test h2[1].q1      == 0.0
    @test h2[1].q2      == 1.0
    @test all(r -> !isnan(r.gamma_L) && !isnan(r.n_air), h2)

    he = h2o.broadeners["He"]
    @test length(he)  == 151
    @test he[1].code    == "a1"
    @test he[1].gamma_L ≈ 0.0219
    @test he[1].n_air   ≈ 0.462
    @test he[1].q1      == 0.0
    @test he[1].q2      == 1.0
  end

  @testset "broad_fallback no-op" begin
    # Isotopologue already has broadeners; broad_fallback returns early
    h2o_fb = load_isotopologue("H2O", "1H2-16O", "POKAZATEL"; wn_range=(41200, 42000), broad_fallback=true)
    @test length(h2o_fb.broadeners) == 2
  end

end
