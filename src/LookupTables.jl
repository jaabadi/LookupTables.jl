module LookupTables

mutable struct LookupTable2D
    xvar::StepRangeLen{Float64}
    yvar::StepRangeLen{Float64}

    xdict::Dict{Float64, Int64}
    ydict::Dict{Float64, Int64}

    vals::Array{Float64, 2}
end

function RangeToDict(z::StepRangeLen)
    zdict = Dict()
    for i in eachindex(z)
        zdict[z[i]] = i
    end
    return zdict
end

function LookupTable2D(xvar::StepRangeLen{Float64}, yvar::StepRangeLen{Float64}, vals::Array{Float64, 2})
    xdict = RangeToDict(xvar)
    ydict = RangeToDict(yvar)

    return LookupTable2D(xvar, yvar, xdict, ydict, vals)
end

function LookupTable2D(xn::Int64, yn::Int64)
    return LookupTable2D(range(0, stop=1, length=xn), range(0, stop=1, length=yn), zeros(xn, yn))
end

function lookup(ltable::LookupTable2D, x::Float64, y::Float64)
    xind = ltable.xdict[x]
    yind = ltable.ydict[y]

    return ltable.vals[xind, yind]
end

export LookupTable2D, lookup

end # module
