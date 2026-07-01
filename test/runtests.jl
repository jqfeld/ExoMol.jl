using ExoMol
using Test
using SafeTestsets

@testset "ExoMol.jl" begin
  @safetestset "Aqua quality assurance" begin include("aqua_tests.jl") end
  @safetestset "Download tests" begin include("download_tests.jl") end
  @safetestset "Isotopologue tests" begin include("isotopologue_tests.jl") end
  @safetestset "H2O POKAZATEL tests" begin include("h2o_tests.jl") end
end
