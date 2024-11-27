using Zygote
using ForwardDiff
using Enzyme
using SpecialFunctions

@testset "alg:$alg" for alg in [JacobiElliptic.CarlsonAlg, ]# JacobiElliptic.FukushimaAlg]
    @testset "Zygote and ForwardDiff" begin

        num_trials = 1
        ms = rand(num_trials)
        ϕs = rand(num_trials) .* 2π
        ns = rand(num_trials)

        @show ms, ϕs, ns

        # Test several known derivative identities across a wide range of values of ϕ and m
        # in order to verify that derivatives work correctly
        @testset for (m, ϕ, n) in zip(ms, ϕs, ns)

            # I. Tests for complete integrals, from https://en.wikipedia.org/wiki/Elliptic_integral
            # 1. K'(m) = E(m) / (2m * (1 - m)) - K(m)/2m
            @testset "Complete K" begin
                grad = (alg.E(m) / (2m * (1 - m)) - alg.K(m) / (2m))
                @test Zygote.gradient(alg.K, m)[1] ≈ grad
                @test ForwardDiff.derivative(alg.K, m) ≈ grad
                @test Enzyme.autodiff(Reverse, alg.K, Active, Active(m))[1][1] ≈ grad
                @test Enzyme.autodiff(Forward, alg.K, Duplicated, Duplicated(m, 1.0))[1][1] ≈ grad
            end

            # 2. E'(m) = (E(m) - K(m))/2m
            @testset "Complete E" begin
                grad = (alg.E(m) - alg.K(m))/2m
                @test Zygote.gradient(alg.E, m)[1] ≈ grad
                @test ForwardDiff.derivative(alg.E, m) ≈ grad
                @test Enzyme.autodiff(Reverse, alg.E, Active, Active(m))[1][1] ≈ grad
                @test Enzyme.autodiff(Forward, alg.E, Duplicated, Duplicated(m, 1.0))[1][1] ≈ grad
            end

            # 3. ∂_n Pi(n, m) = (E(m) + (m-n)*K(m)/n + (n^2-m)*Pi(n,m)/n)/(2*(m-n)*(n-1))
            @testset "Complete Pi" begin
                _Pi = alg.Pi
                grad = (alg.E(m)/(m-1) + _Pi(n, m))/(2*(n-m))
                @test Zygote.gradient(m->_Pi(n, m), m)[1] ≈ grad
                @test ForwardDiff.derivative(m->_Pi(n, m), m) ≈ grad
                @test Enzyme.autodiff(Reverse, _Pi, Active, Const(n), Active(m))[1][2] ≈ grad
            end

            # II. Tests for incomplete integrals, from https://functions.wolfram.com/EllipticIntegrals/EllipticF/introductions/IncompleteEllipticIntegrals/ShowAll.html
            @testset "Incomplete F" begin
                _F = alg.F

                # 4. ∂ϕ(F(ϕ, m)) == 1 / √(1 - m*sin(ϕ)^2)
                grad = 1 / √(1 - m*sin(ϕ)^2)
                @test Zygote.gradient(ϕ -> _F(ϕ, m), ϕ)[1] ≈ grad atol=1e-5
                @test ForwardDiff.derivative(ϕ -> _F(ϕ, m), ϕ) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _F, Active, Active(ϕ), Const(m))[1][1] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _F, Duplicated, Duplicated(ϕ, 1.0), Const(m))[1][1] ≈ grad atol=1e-5

                # 5. ∂m(F(ϕ, m)) == E(ϕ, m) / (2 * m * (1 - m)) - F(ϕ, m) / 2m - sin(2ϕ) / (4 * (1-m) * √(1 - m * sin(ϕ)^2))
                grad = alg.E(ϕ, m) / (2 * m * (1 - m)) -
                    alg.F(ϕ, m) / 2 / m -
                    sin(2*ϕ) / (4 * (1 - m) * √(1 - m * sin(ϕ)^2))
                @test Zygote.gradient(m -> _F(ϕ, m), m)[1] ≈ grad atol=1e-5
                @test ForwardDiff.derivative(m -> _F(ϕ, m), m) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _F, Active, Const(ϕ), Active(m))[1][2] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _F, Duplicated, Const(ϕ), Duplicated(m, 1.0))[1][1] ≈ grad atol=1e-5
            end

            @testset "Incomplete E" begin
                _E = alg.E

                # 6. ∂ϕ(E(ϕ, m)) == √(1 - m * sin(ϕ)^2)
                grad = √(1 - m * sin(ϕ)^2)
                @test Zygote.gradient(ϕ -> _E(ϕ, m), ϕ)[1] ≈ grad atol=1e-5
                @test ForwardDiff.derivative(ϕ -> _E(ϕ, m), ϕ) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _E, Active, Active(ϕ), Const(m))[1][1] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _E, Duplicated, Duplicated(ϕ, 1.0), Const(m))[1][1] ≈ grad atol=1e-5

                # 7. ∂m(E(ϕ, m)) == (E(ϕ, m) - F(ϕ, m)) / 2m
                grad = (alg.E(ϕ, m) - alg.F(ϕ, m)) / 2m
                @test Zygote.gradient(m -> _E(ϕ, m), m)[1] ≈  grad atol=1e-5
                @test ForwardDiff.derivative(m -> _E(ϕ, m), m) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _E, Active, Const(ϕ), Active(m))[1][2] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _E, Duplicated, Const(ϕ), Duplicated(m, 1.0))[1][1] ≈ grad atol=1e-5
            end
            @testset "Incomplete Pi" begin
                _Pi = alg.Pi

                # 7. ∂n(Pi(n, ϕ, m))
                grad = (alg.E(ϕ, m) + (m-n)*alg.F(ϕ, m)/n + (n^2-m)*_Pi(n, ϕ, m)/n -n*√(1-m*sin(ϕ)^2)*sin(2ϕ)/(2*(1-n*sin(ϕ)^2)))/(2*(m-n)*(n-1))
                @test Zygote.gradient(n -> _Pi(n, ϕ, m), n)[1] ≈ grad atol=1e-5
                @test ForwardDiff.derivative(n -> _Pi(n, ϕ, m), n) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _Pi, Active, Active(n), Const(ϕ), Const(m))[1][1] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _Pi, Duplicated, Duplicated(n, 1.0), Const(ϕ), Const(m))[1][1] ≈ grad atol=1e-5


                # 8. ∂ϕ(Pi(n, ϕ, m))
                grad = 1/(√(1 - m * sin(ϕ)^2)*(1-n*sin(ϕ)^2))
                @test Zygote.gradient(ϕ -> _Pi(n, ϕ, m), ϕ)[1] ≈ grad atol=1e-5
                @test ForwardDiff.derivative(ϕ -> _Pi(n, ϕ, m), ϕ) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _Pi, Active, Const(n), Active(ϕ), Const(m))[1][2] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _Pi, Duplicated, Const(n), Duplicated(ϕ, 1.0), Const(m))[1][1] ≈ grad atol=1e-5

                # 9. ∂m(Pi(n, ϕ, m))
                grad = (alg.E(ϕ, m)/(m-1) + _Pi(n, ϕ, m) - m*sin(2ϕ)/(2*(m-1)*√(1-m*sin(ϕ)^2))) / 2(n-m)
                @test Zygote.gradient(m -> _Pi(n, ϕ, m), m)[1] ≈  grad atol=1e-5
                @test ForwardDiff.derivative(m -> _Pi(n, ϕ, m), m) ≈ grad atol=1e-5
                @test Enzyme.autodiff(Reverse, _Pi, Active, Const(n), Const(ϕ), Active(m))[1][3] ≈ grad atol=1e-5
                @test Enzyme.autodiff(Forward, _Pi, Duplicated, Const(n), Const(ϕ), Duplicated(m, 1.0))[1][1] ≈ grad atol=1e-5
            end

        end
    end

    @testset "SpecialCases" begin
        _E = alg.E
        @test ForwardDiff.gradient(x -> _E(x[1], x[2]), [π/2.0, 0.0]) |> collect ≈  [1.0, -π/8]
        @test Enzyme.autodiff(Reverse, _E, Active, Active(π/2.0), Active(0.0))[1] |> collect ≈  [1.0, -π/8]
        @test Zygote.gradient(x -> _E(x[1], x[2]), [π/2.0, 0.0])[1] ≈  [1.0, -π/8]

    end

end