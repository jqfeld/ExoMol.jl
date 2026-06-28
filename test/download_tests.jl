using ExoMol
using Test

db = get_exomol_master()
@test db["ID"] == "EXOMOL.master"
@test haskey(db, "version")
@test haskey(db, "molecules")
@test haskey(db, "num_isotopologues")
@test haskey(db, "num_datasets")
@test haskey(db, "num_molecules")
@test length(db["molecules"]) == db["num_molecules"]

@testset "save_dataset" begin
  dest = mktempdir()
  result = save_dataset(dest, "N2", "14N2", "WCCRMT")
  @test result == dest
  saved = readdir(dest)
  @test "14N2__WCCRMT.def.json" in saved
  @test "14N2__WCCRMT.states.bz2" in saved
  @test "14N2__WCCRMT.trans.bz2" in saved
  @test "14N2__WCCRMT.pf" in saved

  # load_isotopologue works on the saved directory
  iso = load_isotopologue(dest)
  @test length(iso.states) == 58380
  @test length(iso.transitions) == 7182000

  # force=false skips existing files (no error)
  save_dataset(dest, "N2", "14N2", "WCCRMT"; force=false)

  # force=true overwrites without error
  save_dataset(dest, "N2", "14N2", "WCCRMT"; force=true)
end

@testset "wn_range filtering" begin
  f = ExoMol._trans_in_wn_range

  # Unsegmented file always passes
  @test f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (500, 600))

  # File fully inside range
  @test f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (250, 500))

  # File starts before range
  @test !f("1H2-16O__BT2__00000-00250.trans.bz2", "1H2-16O", "BT2", (100, 1000))

  # File ends after range
  @test !f("1H2-16O__BT2__00500-01000.trans.bz2", "1H2-16O", "BT2", (0, 900))

  # Unrecognised suffix → excluded
  @test !f("1H2-16O__BT2__ERJ.trans.bz2", "1H2-16O", "BT2", (0, 99999))
end
