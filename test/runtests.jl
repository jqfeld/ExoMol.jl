using ExoMol
using Test
using SafeTestsets

@testset "ExoMol.jl" begin
    # Write your tests here.
  @safetestset "Definitions tests" begin include("definitions_tests.jl") end
end
