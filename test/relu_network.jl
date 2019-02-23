
@testset "ReLU Last Layer" begin

    small_nnet_file = "$(@__DIR__)/../examples/networks/small_nnet.nnet"
    # small_nnet encodes the simple function 24*max(x + 1.5, 0) + 18.5
    small_nnet = read_nnet(small_nnet_file, last_layer_activation = ReLU())

    # The input set is ⊂[-1:1]
    input_hyper  = Hyperrectangle(low = [-0.9], high = [0.9])
    input_hpoly  = convert(HPolytope, input_hyper)

    # Output region is entirely contained in this interval:
    out_superset     = Hyperrectangle(low = [20.0], high = [90.0])    # 20.0 ≤ y ≤ 90.0
    # Includes some points in the output region but not all:
    out_overlapping  = Hyperrectangle(low = [-1.0], high = [50.0])    # -1.0 ≤ y ≤ 50.0

    problem_sat_hyper_hyper           = Problem(small_nnet, input_hyper, out_superset)
    problem_unsat_hyper_hyper         = Problem(small_nnet, input_hyper, out_overlapping)
    problem_sat_hpoly_hpoly_bounded   = Problem(small_nnet, input_hpoly, convert(HPolytope, out_superset))
    problem_unsat_hpoly_hpoly_bounded = Problem(small_nnet, input_hpoly, convert(HPolytope, out_overlapping))
    # halfspace only constraints:
    problem_sat_hyper_hs              = Problem(small_nnet, input_hyper, HPolytope([HalfSpace([1.], 100.)]))     # y < 100.0
    problem_unsat_hyper_hs            = Problem(small_nnet, input_hyper, HPolytope([HalfSpace([1.], 10.)]))      # y < 10.0

    @testset "Group 1" begin
        for solver in [MaxSens(resolution = 0.6), ExactReach(), Ai2()]
            sat   = solve(solver, problem_sat_hpoly_hpoly_bounded)
            unsat = solve(solver, problem_unsat_hpoly_hpoly_bounded)

            @test sat.status ∈ (:SAT, :Unknown)
            @test unsat.status ∈ (:UNSAT, :Unknown)
        end

    end

    @testset "Group 2, 3, 4, 6" begin
        glpk = GLPKSolverMIP()

        group2 = [S(optimizer = glpk) for S in (NSVerify, MIPVerify, ILP)]
        group3 = [Duality(optimizer = glpk)] # hypothetically also ConvDual
        group4 = [FastLin(), FastLip()]
        group6 = [Reluplex(), Planet()]

        for solver in [group2; group3; group4; group6]
            sat   = solve(solver, problem_sat_hyper_hs)
            unsat = solve(solver, problem_unsat_hyper_hs)

            @test sat.status ∈ (:SAT, :Unknown)
            @test unsat.status ∈ (:UNSAT, :Unknown)
        end

        # ConvDual can not handle ReLU networks at present.
        # We should ignore the result even if this particular network is trivial
        sat   = solve(ConvDual(), problem_sat_hyper_hs)
        unsat = solve(ConvDual(), problem_unsat_hyper_hs)
        @test_skip sat.status ∈ (:SAT, :Unknown)
        @test_skip unsat.status ∈ (:UNSAT, :Unknown)
    end

    @testset "Group 5" begin
        for solver in [ReluVal(max_iter = 10), DLV(), Sherlock(glpk, 0.5), BaB(optimizer = glpk)]
            sat   = solve(solver, problem_sat_hyper_hyper)
            unsat = solve(solver, problem_unsat_hyper_hyper)

            @test sat.status ∈ (:SAT, :Unknown)
            @test unsat.status ∈ (:UNSAT, :Unknown)
        end
    end

    @testset "Certify" begin
        ### Certify - only works for single hidden layer
        tiny_nnet = read_nnet("$(@__DIR__)/../examples/networks/tiny_nnet.nnet")
        solver_certify = Certify()
        inputSet  = Hyperrectangle([2.0], [.5])
        outputSet = HPolytope(ones(1,1), [2.5])
        problem_certify = Problem(tiny_nnet, inputSet, outputSet)
        @test @no_error solve(solver_certify, problem_certify)
    end
end