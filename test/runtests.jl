using ConstrainedOptim
COpt = ConstrainedOptim
using Optim
using Base.Test

@testset "Finite Difference Testing" begin
    f(x) = x[1]^2 + x[2]^2 + x[2]^4
    df(x) = [2*x[1], 2*x[2]+4*x[2]^3]
    c(x) = x[1]^2 + (x[2]-0.5)^2 - 2.0
    dc(x) = [ 2*x[1] 2*(x[2]-0.5) ]

    # the minimiser should be [0.0,0.0]
    x0 = [1.0, 0.0]


    F = DifferentiableFunction(f, (x,g) -> copy!(g, df(x)) )
    C = EqualityConstraint(c, (x,g) -> copy!(g, dc(x)) )


    println("------------------------------------------------------------")
    println("       Finite Difference Testing the AL ")
    @printf("   h   |   err \n")
    @printf("-------|-------------\n")
    # finite-difference test of the augmented Lagrangian implementation
    al = COpt.AugmentedLagrangian(F, C, x0)
    al.lambda = 0.0
    al.mu = 1.0
    A = COpt.evaluate(x0, al)
    dA = COpt.gradient(x0, al)
    err = Float64[]
    for p = 2:12
       h = 0.1^p
       dAh = zeros(dA)
       for n = 1:length(x0)
          x0[n] += h
          dAh[n] = (COpt.evaluate(x0, al) - A)  / h
          x0[n] -= h
       end
       push!(err, vecnorm(dA - dAh, Inf))
       @printf(" 1e-%2d |  %1.4e \n", p, err[end])
    end
    @test minimum(err) < 1e-4 * err[1]
    if minimum(err) < 1e-4 * err[1]
       println("looks like the FD test has passed...")
    else
       warn("""the finite difference test for the augmented Lagrangien didn't
             pass; please check visually what happened and debug""")
    end


    println("------------------------------------------------------------")
    println("      Try to optimise something simple")
    x, al = ConstrainedOptim.optimize(F, C, x0)
    println("Converged to ", x, "; λ = ", al.lambda)
    println("First-order optimality: ")
    al.mu = 0.0; g = COpt.gradient(x, al); C = al.C.c(x)
    println("   ∇ₓL(x, λ) = ", g)
    println("        c(x) = ", C)
    println("  |∇L(x, λ)| = ", max(vecnorm(g), vecnorm(C)))
    @test vecnorm(g) < 1e-6
    @test vecnorm(C) < 1e-6
    end

# Another test case
@testset "Simple problems" begin
    let
        f(x) = 2x[1]^2+x[2]^2
        ∇f(x) = [4x[1], 2x[2]]
        c(x) = sum(x)-1
        ∇c(x) = ones(1,2)
        initial_x = [0.3,0.75]
        solution_x = [1/3, 2/3]
        F = DifferentiableFunction(f, (x,g) -> copy!(g, ∇f(x)))
        C = EqualityConstraint(c, (x,g) -> copy!(g, ∇c(x)) )

        x, al = ConstrainedOptim.optimize(F, C, initial_x)
        @test norm(x - solution_x, Inf) < 1e-6
    end

    let
        f(x) = -prod(x)
        ∇f(x) = [-x[2]; -x[1]]
        c(x) = sum(x)-6
        ∇c(x) = ones(1,2)
        initial_x = [2.0, 2.0]
        solution_x = [3.0, 3.0]
        F = DifferentiableFunction(f, (x,g) -> copy!(g, ∇f(x)))
        C = EqualityConstraint(c, (x,g) -> copy!(g, ∇c(x)) )

        x, al = ConstrainedOptim.optimize(F, C, initial_x)
        @test norm(x - solution_x, Inf) < 1e-6
    end

    @testset "Cobb-Douglas Cost Minimization" begin
        # Ref: any microeconomics text book

        # Factor prices
        w = [1., 1.]

        # Output elasticities of the factors
        γ = [0.25, 0.75]

        # Quantity to be produced
        q = 2.

        # Cost
        f(x) = dot(w,x)
        ∇f(x) = [w[1], w[2]]

        # Cobb-Douglas Production function
        c(x) = (x[1]^γ[1])*(x[2]^γ[2])-q
        ∇c(x) = [γ[1]*(x[1]^(γ[1]-1))*(x[2]^γ[2]) (x[1]^γ[1])*γ[2]*(x[2]^(γ[2]-1))]

        # Some guess (it doesn't even produce the correct amount...)
        initial_x = [1., 2.]

        # Analytical solution
        solution_x = [(w[2]/w[1])*(γ[1]/γ[2])^(γ[2]/sum(γ))*q^(1/sum(γ));(w[1]/w[2])*(γ[2]/γ[1])^(γ[1]/sum(γ))*q^(1/sum(γ))]

        F = DifferentiableFunction(f, (x,g) -> copy!(g, ∇f(x)))
        C = EqualityConstraint(c, (x,g) -> copy!(g, ∇c(x)) )

        x, al = ConstrainedOptim.optimize(F, C, initial_x)
        @test norm(x - solution_x, Inf) < 1e-6
    end

    @testset "Nocedal-Wright examples" begin
        let # 17.1
            f(x) = x[1]+x[2]
            ∇f(x) = [1., 1.]
            c(x) = x[1]^2+x[2]^2-2
            ∇c(x) = [2*x[1] 2*x[2]]

            # Initial value is arbitrary...
            initial_x = [-0.3, -0.5]
            solution_x = [-1.0, -1.0]
            F = DifferentiableFunction(f, (x,g) -> copy!(g, ∇f(x)))
            C = EqualityConstraint(c, (x,g) -> copy!(g, ∇c(x)) )

            x, al = ConstrainedOptim.optimize(F, C, initial_x)
            @test norm(x - solution_x, Inf) < 1e-6
        end

        let # Page 500
            f(x) = -5x[1]^2+x[2]^2
            ∇f(x) = [-10.0x[1], 2.0x[2]]
            c(x) = x[1]-1
            ∇c(x) = [1  0]

            # Initial value is arbitrary...
            initial_x = [3., 0.5]
            solution_x = [1.0, 0.0]
            F = DifferentiableFunction(f, (x,g) -> copy!(g, ∇f(x)))
            C = EqualityConstraint(c, (x,g) -> copy!(g, ∇c(x)) )

            x, al = ConstrainedOptim.optimize(F, C, initial_x)
            @test norm(x - solution_x, Inf) < 1e-6
        end

        @testset "Simple Convex Constraints on x" begin
            eta = 0.9

            function f_gd_2(x)
              (1.0 / 2.0) * (x[1]^2 + eta * x[2]^2)
            end

            function g_gd_2(x, storage)
              storage[1] = x[1]
              storage[2] = eta * x[2]
            end

            d = DifferentiableFunction(f_gd_2, g_gd_2)
            box_c = BoxConstraint(fill(-1.0, 2), fill(1.0, 2))
            ball_c = BallConstraint(fill(0.0, 2), 1.0, 2)
            res_unc = Optim.optimize(d, [1.0, 1.0], GradientDescent(linesearch! = Optim.backtracking_linesearch!))
            res_con_box = optimize(d, [1.0, 1.0], box_c, ProjectedGradientDescent(), OptimizationOptions())
            res_con_ball = optimize(d, [1.0, 1.0], ball_c, ProjectedGradientDescent(), OptimizationOptions())

            @test Optim.minimum(res_unc) == Optim.minimum(res_con_box) == Optim.minimum(res_con_ball)
        end
    end
end
