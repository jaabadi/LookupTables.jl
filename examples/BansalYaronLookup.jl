using EconPDEs, Distributions, LookupTables

mutable struct BansalYaronModel
    # consumption process parameters
    μbar::Float64
    vbar::Float64
    κμ::Float64
    νμ::Float64
    κv::Float64
    νv::Float64

    # utility parameters
    ρ::Float64
    γ::Float64
    ψ::Float64

    # lookup
    μn::Int64
    vn::Int64
    τ::LookupTable2D
end

function BansalYaronModel(;μbar = 0.018, vbar = 0.00073, κμ = 0.252, νμ = 0.528, κv = 0.156, νv = 0.00354, ρ = 0.024, γ = 7.5, ψ = 1.5, μn=30, vn=30, τ=LookupTable2D(30, 30))
    BansalYaronModel(μbar, vbar, κμ, νμ, κv, νv, ρ, γ, ψ, μn, vn, τ)
end

function initialize_stategrid(m::BansalYaronModel)
    μbar = m.μbar ; vbar = m.vbar ; κμ = m.κμ ; νμ = m.νμ ; κv = m.κv ; νv = m.νv ; ρ = m.ρ ; γ = m.γ ; ψ = m.ψ
    μn = m.μn ; vn = m.vn

    σ = sqrt(νμ^2 * vbar / (2 * κμ))
    μmin = quantile(Normal(μbar, σ), 0.025)
    μmax = quantile(Normal(μbar, σ), 0.975)
    μs = range(μmin, stop = μmax, length = μn)

    α = 2 * κv * vbar / νv^2
    β = νv^2 / (2 * κv)
    vmin = quantile(Gamma(α, β), 0.025)
    vmax = quantile(Gamma(α, β), 0.975)
    vs = range(vmin, stop = vmax, length = vn)
    OrderedDict(:μ => μs, :v => vs)
end

function initialize_y(m::BansalYaronModel, stategrid::OrderedDict)
    OrderedDict(:p => ones(length(stategrid[:μ]), length(stategrid[:v])))
end

function update_τ(m::BansalYaronModel, stategrid::OrderedDict, τmat::Array{Float64, 2})
    m.τ = LookupTable2D(stategrid[:μ], stategrid[:v], τmat)
    m.τ.xvar = stategrid[:μ]
    m.τ.yvar = stategrid[:v]
end

function (m::BansalYaronModel)(state::NamedTuple, y::NamedTuple)
    μbar = m.μbar ; vbar = m.vbar ; κμ = m.κμ ; νμ = m.νμ ; κv = m.κv ; νv = m.νv ; ρ = m.ρ ; γ = m.γ ; ψ = m.ψ ; τ = m.τ
    μ, v = state.μ, state.v
    p, pμ, pv, pμμ, pμv, pvv = y.p, y.pμ, y.pv, y.pμμ, y.pμv, y.pvv

    τvar = lookup(τ, μ, v)
    τnew = μ^2 - v * μ

    # drift and volatility of c, μ, σ, p
    μc = μ
    σc = sqrt(v)
    μμ = κμ * (μbar - μ)
    σμ = νμ * sqrt(v)
    μv = κv * (vbar - v)
    σv = νv * sqrt(v)
    σp_Zμ = pμ / p * σμ
    σp_Zv = pv / p * σv
    σp2 = σp_Zμ^2 + σp_Zv^2
    μp = pμ / p * μμ + pv / p * μv + 0.5 * pμμ / p * σμ^2 + 0.5 * pvv / p * σv^2

    # Market price of risk κ
    κ_Zc = γ * σc
    κ_Zμ = - (1 - γ * ψ) / (ψ - 1) * σp_Zμ
    κ_Zv = - (1 - γ * ψ) / (ψ - 1) * σp_Zv
    κ2 = κ_Zc^2 + κ_Zμ^2 + κ_Zv^2

    # Risk free rate r
    r = ρ + μc / ψ - (1 + 1 / ψ) / 2 * γ * σc^2 - (γ * ψ - 1) / (2 * (ψ - 1)) * σp2

    # Market Pricing
    # pt = p * (1 / p + μc + μp - r - κ_Zc * σc - κ_Zμ * σp_Zμ - κ_Zv * σp_Zv)
    pt = p * (1 / p - ρ + (1 - 1 / ψ) * (μc - 0.5 * γ * σc^2) + μp + 0.5 * (1 / ψ - γ) / (1 - 1 / ψ) * σp2)

    # return (pt,), (μμ, μv), (p = p, r = r, κ_Zc = κ_Zc, κ_Zμ = κ_Zμ, κ_Zv = κ_Zv, σμ = σμ, σμ_Zv = 0.0, σv_Zμ = 0.0, σv = σv, μ = μ, v = v, σμ2 = σμ^2, σv2 = σv^2, σμv = 0.0, μμ = μμ, μv = μv, σp2 = σp2, σp_Zμ = σp_Zμ, σp_Zv = σp_Zv)
    return (pt,), (μμ, μv), (p = p, μμ = μμ, σμ = σμ, μv = μv, σv = σv, τnew = τnew, μ = μ, v = v)
end

# Bansal Yaron (2004)
m = BansalYaronModel()
stategrid = initialize_stategrid(m)
y0 = initialize_y(m, stategrid)
update_τ(m, stategrid, zeros(m.μn, m.vn))
y, result, distance = pdesolve(m, stategrid, y0)

update_τ(m, stategrid, result[:τnew])
