using LookupTables
using Test

@testset "LookupTables.jl" begin
    nx = 100
    ny = 50

    y = range(13.7, step = 0.5, length = 50)
    x = range(0.0, step = 0.1, length = 100)

    vals = zeros(nx, ny)

    for i in eachindex(x)
        for j in eachindex(y)
            vals[i, j] = x[i]^2 - 3 * x[i] * y[j]
        end
    end

    ltable = LookupTable2D(x, y, vals)

    using BenchmarkTools

    @btime lookup(ltable, 4.4, 22.2)

    @btime [[lookup(ltable, xval, yval) for xval in x] for yval in y]

end
