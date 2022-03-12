# common method
function relevanttime(spins::Union{SpinCluster,SpinEnsemble}, n_t::Int; scale::Real = 1.0)
    T2 = coherencetime(spins) * scale
    return 0:T2/n_t:T2
end

# dynamics
@doc raw"""
    fid(t, M, sampling_D; [options]...)
    fid(t, M, sampling_D; [options]...)

Calculate the average free induction decay over different ensembles (disorders) 

```math
\bar{f}(t)=\sum_k f(t; \{D_i\}_k)
```

# Arguments
- `t`: the time array for the decay curve.
- `M`: number of ensembles
- `ensemble`: spin ensemble
- `sampling_D`: the function to sample over D
"""
function fid(
    t::AbstractVector{Float64},
    ensemble::SpinEnsemble,
    h::Real = 0;
    M::Int = 200,
    N::Int = 100,
    geterr::Bool = false,
)
    f_sum = zeros(length(t))
    f_var = copy(f_sum)
    cluster = SpinCluster(ensemble)
    @showprogress for i = 1:M
        f_d = fid(t, cluster, h; N = N)
        f_sum += f_d
        f_var += i > 1 ? (i * f_d - f_sum) .^ 2 / (i * (i - 1)) : f_var
        reroll!(cluster)
    end
    if geterr
        return f_sum / M, f_var / (M - 1)
    else
        return f_sum / M
    end
end


function rabi(
    t::AbstractVector{Float64},
    ensemble::SpinEnsemble,
    h::Real;
    M::Int = 200,
    N::Int = 100,
    axis::Int = 3,
    geterr::Bool = false,
)
    f_sum = zeros(length(t))
    f_var = copy(f_sum)
    cluster = SpinCluster(ensemble)
    @showprogress for i = 1:M
        f_d = rabi(t, cluster, h; N = N, axis = axis)
        f_sum += f_d
        f_var += i > 1 ? (i * f_d - f_sum) .^ 2 / (i * (i - 1)) : f_var
        reroll!(cluster)
    end
    if geterr
        return f_sum / M, f_var / (M - 1)
    else
        return f_sum / M
    end
end


@doc raw"""
    fid(t, D, h; N)

Calculate the free induction dacay of the given spin cluster,
with given transverse magnetic field, using Monte-Carlo sampling

```math
f_p(t)=\frac{1}{2}[\cos^2(\omega_p t)+\sin^2(\omega_p t) (n_x^2-n_z^2)]
```

```math
\bar{f}(t)=\frac{1}{N}\sum_{p=1}^N f_p(t)
```

when h=0, the equation is reduced to 

```math
f(t)=\frac{1}{2}\prod_j \cos(D_jt)
```

# Arguments
- `t`: discrete array marking time 
- `D`: a set of the coupling strengths
- `h`: strength of transverse field 

# Options
- `N`: number of Monte-Carlo sampling
- `geterr::Bool`: wetehr to return the error of the monte-sampling 
"""
function fid(
    t::AbstractVector{Float64},
    cluster::SpinCluster,
    h::Real = 0;
    N::Int = 100,
    geterr::Bool = false,
)
    D = cluster.couplings

    if h == 0
        return [mapreduce(cos, *, D * τ) / 2 for τ in t]
    end

    n = length(D)
    f_sum = zeros(length(t)) # sum
    f_var = copy(f_sum) # square sum
    for i = 1:N
        β_p = sum(rand([1, -1], n) .* D)
        ω_p = sqrt(h^2 + β_p^2) / 2
        cos2_p = cos.(ω_p * t) .^ 2
        f_p = (cos2_p + (cos2_p .- 1) * (β_p^2 - h^2) / (h^2 + β_p^2)) / 2
        f_sum += f_p
        f_var += i > 1 ? (i * f_p - f_sum) .^ 2 / (i * (i - 1)) : f_var
    end
    if geterr
        return (f_sum / N, f_var / (N - 1))
    else
        return f_sum / N
    end
end


@doc raw"""
    rabi(t, D, h; N, options...)

Get a random sampling of, under given transverse magnetic field

```math
\begin{aligned}
z_p(t)&=+\frac{1}{2} \left[n_z^2+n_x^2 \cos (\Omega_p t)\right]\\
y_p(t)&=-\frac{1}{2} n_x \sin (\Omega_p t)\\
x_p(t)&=+\frac{1}{2} \left[n_x n_z-n_x n_z \cos (\Omega_p t)\right]
\end{aligned}
```

```math
G(t)=\frac{1}{N}\sum_{p=1}^N g_p(t),\; g=x,y,z
```

# Arguments
- `t`: discrete array marking time 
- `D`: a set of the coupling strengths
- `h`: strength of transverse field 

# Options
- `N`: size of Monte-Carlo sampling, default at 100
- `axis::Int`: , 1,2,3, representing x,y,z axis, set to 3 by default 
- `geterr::Bool`: wether to return the variance in sampling
"""
function rabi(
    t::AbstractVector{Float64},
    cluster::SpinCluster,
    h::Real;
    N::Int = 100,
    axis::Int = 3,
    geterr::Bool = false,
)
    @assert axis in (1, 2, 3)

    D = cluster.couplings
    n = length(D)
    f_sum = zeros(length(t)) # sum
    f_var = copy(f_sum) # square sum
    f_sampling = (_rabix, _rabiy, _rabiz)[axis]

    for i = 1:N
        β_p = sum(rand([1, -1], n) .* D)
        f_p = f_sampling(t, β_p, h)
        f_sum += f_p
        f_var += i > 1 ? (i * f_p - f_sum) .^ 2 / (i * (i - 1)) : f_var
    end
    if geterr
        return (f_sum / N, f_var / (N - 1))
    else
        return f_sum / N
    end
end


function _rabiz(t::AbstractVector{<:Real}, β::Real, h::Real)
    Ω = sqrt(h^2 + β^2)
    return (β^2 .+ h^2 * cos.(Ω * t) ) / (2*Ω^2)
end

function _rabiy(t::AbstractVector{<:Real}, β::Real, h::Real)
    Ω = sqrt(h^2 + β^2)
    return -sin.(Ω * t)* h / (2Ω)
end

function _rabix(t::AbstractVector{<:Real}, β::Real, h::Real)
    Ω = sqrt(h^2 + β^2)
    return β*h * (1 .- cos.(Ω * t))  / (2*Ω^2)
end

"""
Get the average driving axis and average driving phase (Rabi frequency) for a spin cluster
""" 
function driving(h::Real, t::Real, cluster::SpinCluster, 
    aim::Vector{<:Real}=[1,0,0]; N::Int=100, sampling::Bool = false)
    normalize!(aim)
    z0=cluster.ensemble.z0
    β_p = betasampling(cluster, N)
    n_p= β_p.*z0' .+ h*aim'
    Ω_p = sqrt.(sum(abs2, n_p, dims=2))

    if sampling
        return vec(t*Ω_p), n_p./Ω_p
    else
        Ω = sum(Ω_p)/N
        n = normalize(sum(n_p, dims=1))
        return Ω*t, vec(n)
    end
end 

"""
Find the Rabi period of the given ensemble under driving field, using linear regression at slope.
"""
function rabiperiod(ensemble::SpinEnsemble, h::Real = 0; 
    M::Int = 1000, N::Int = 100, λ::Real = 0.1, L::Int = 20) # short length fitting 
    Γ = dipolarlinewidth(ensemble, M=M) 
    ω = sqrt(h^2+Γ^2)
    t0 = π/(2*ω)
    t = LinRange(t0*(1-λ),t0*(1+λ), L)
    curve=rabi(t, ensemble, h; M=M, N=N)
    # linear regression
    m(t, p) = p[1] * t .+ p[2]
    p0 = [-ω, π/2]
    fit = curve_fit(m, t, curve, p0) 
    (k,b) = fit.param
    return -2*b/k
end