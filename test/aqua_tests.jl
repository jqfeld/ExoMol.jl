using Test
using ExoMol
using Aqua

@testset "Aqua" begin
    Aqua.test_all(ExoMol; ambiguities=(recursive=false))
end
