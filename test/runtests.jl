using ExoMol
using Test
using SafeTestsets

# Set EXOMOL_TEST_NETWORK=false to skip the tests that download from exomol.com.
const NETWORK = get(ENV, "EXOMOL_TEST_NETWORK", "true") != "false"

@testset "ExoMol.jl" begin
  @safetestset "Aqua quality assurance" begin include("aqua_tests.jl") end
  @safetestset "Parser tests" begin include("parser_tests.jl") end
  if NETWORK
    @safetestset "Download tests" begin include("download_tests.jl") end
    @safetestset "Isotopologue tests" begin include("isotopologue_tests.jl") end
    @safetestset "H2O POKAZATEL tests" begin include("h2o_tests.jl") end
  else
    @info "EXOMOL_TEST_NETWORK=false: skipping tests that download from exomol.com"
  end
end
