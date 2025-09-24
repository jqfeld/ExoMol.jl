using ExoMol
using Test
using SafeTestsets

@testset "ExoMol.jl" begin
    # Write your tests here.
  @safetestset "Download tests" begin include("download_tests.jl") end
  @safetestset "Isotopologue tests" begin include("isotopologue_tests.jl") end
end
