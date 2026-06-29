using ExoMol
using Test

@testset "master database" begin
  db = get_exomol_master()
  @test db["ID"] == "EXOMOL.master"
  @test haskey(db, "version")
  @test haskey(db, "molecules")
  @test haskey(db, "num_isotopologues")
  @test haskey(db, "num_datasets")
  @test haskey(db, "num_molecules")
  @test length(db["molecules"]) == db["num_molecules"]
end

@testset "save_dataset" begin
  get_exomol_dataset("N2", "14N2", "WCCRMT")
  dest = mktempdir()
  result = save_dataset(dest, "N2", "14N2", "WCCRMT")
  @test result == dest
  saved = readdir(dest)
  @test "14N2__WCCRMT.def.json" in saved
  @test "14N2__WCCRMT.states.bz2" in saved
  @test "14N2__WCCRMT.trans.bz2" in saved
  @test "14N2__WCCRMT.pf" in saved

  iso = load_isotopologue(dest)
  @test length(iso.states) == 58380
  @test length(iso.transitions) == 7182000
  @test isempty(iso.broadeners)

  save_dataset(dest, "N2", "14N2", "WCCRMT"; force=false)
  save_dataset(dest, "N2", "14N2", "WCCRMT"; force=true)
end

@testset "wn_range filtering" begin
  f = ExoMol._trans_in_wn_range

  # Unsegmented file always passes
  @test  f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (500, 600))

  # File fully inside range
  @test  f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (250, 500))

  # Exact boundary: lower == wn_min and upper == wn_max
  @test  f("1H2-16O__BT2__00000-00100.trans.bz2", "1H2-16O", "BT2", (0, 100))

  # File straddles upper bound → excluded
  @test !f("1H2-16O__BT2__00900-01100.trans.bz2", "1H2-16O", "BT2", (0, 1000))

  # File starts below lower bound → excluded
  @test !f("1H2-16O__BT2__00000-00250.trans.bz2", "1H2-16O", "BT2", (100, 1000))

  # File ends above upper bound → excluded
  @test !f("1H2-16O__BT2__00500-01000.trans.bz2", "1H2-16O", "BT2", (0, 900))

  # Unrecognised suffix → excluded
  @test !f("1H2-16O__BT2__ERJ.trans.bz2", "1H2-16O", "BT2", (0, 99999))
end

@testset "read_broad_file" begin
  path = tempname()
  write(path, "a0 0.07 0.5\na1 0.0916 0.790 0 1\n\n")
  records = read_broad_file(path)
  rm(path)

  @test length(records) == 2
  @test records[1].code    == "a0"
  @test records[1].gamma_L ≈ 0.07
  @test records[1].n_air   ≈ 0.5
  @test isnan(records[1].q1)
  @test isnan(records[1].q2)
  @test records[2].code    == "a1"
  @test records[2].gamma_L ≈ 0.0916
  @test records[2].n_air   ≈ 0.790
  @test records[2].q1      == 0.0
  @test records[2].q2      == 1.0
end
