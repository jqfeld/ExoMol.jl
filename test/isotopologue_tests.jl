using Test
using ExoMol

n2 = load_isotopologue("N2", "14N2", "WCCRMT")

@testset "Nitrogen" begin
  @test haskey(n2.definitions, "dataset")
  @test haskey(n2.definitions, "isotopologue")
  @test haskey(n2.definitions, "partition_function")
  @test haskey(n2.definitions, "broad")
  @test haskey(n2.definitions, "atoms")
  @test haskey(n2.definitions, "irreducible_representations")

  @test n2.definitions["isotopologue"]["iso_slug"] == "14N2"
  @test n2.definitions["atoms"]["element"]["N"] == 14
  @test n2.definitions["atoms"]["number_of_atoms"] == 2


  @test length(n2.states) == 58380

  @test n2.states[1].ID == 1
  @test n2.states[1].E == 59266.252923
  @test n2.states[1].var"hunda:ElecState" == "B3Pig"

  @test n2.states[1000].ID == 1000
  @test n2.states[1000].E == 64358.85344
  @test n2.states[1000].var"hunda:ElecState" == "B3Pig"

  @test n2.states[58380].ID == 58380
  @test n2.states[58380].E == 130072.954819
  @test n2.states[58380].var"hunda:ElecState" == "C3Piu"


  @test length(n2.transitions) == 7182000

  @test n2.transitions[1].lower_id == 27271
  @test n2.transitions[1].upper_id ==  6853
  @test n2.transitions[1].wavenumber == 0.000147

  @test n2.transitions[7182000].lower_id == 14821
  @test n2.transitions[7182000].upper_id == 1080
  @test n2.transitions[7182000].wavenumber == 46379.313372


end
