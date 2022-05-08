function unitary(pulse::SquarePulse, β::Real=0, z0::Vector{<:Real}=[0,0,1])
    return rotation(pulse.aim.*pulse.h + z0.*β, pulse.t)
end

function unitary(pulse::Idle, β::Real=0, z0::Vector{<:Real}=[0,0,1])
    return rotation(z0.*β, pulse.t)
end


function krausoperators(pulse::Pulse, β::AbstractVector{<:Real},
    c::Vector{<:Real}=normalize!(ones(size(β)), 1),
    z0::Vector{<:Real}=[0,0,1]
    )::Vector{<:Matrix}
    return sqrt.(c).*[unitary(pulse, β_k, z0) for β_k in β]
end


function unitary(seq::Sequence, β::Real=0, z0::Vector{<:Real}=[0,0,1])
    U0=unitary(seq.idle,β,z0)
    Un=[unitary(g,β,z0) for g in seq.gates]
    V=σ_i
    for i in seq.order
        U= i==0 ? U0 : (sign(i)>0 ? Un[abs(i)] : Un[abs(i)]')
        V=U*V
    end
    return V
end

function krausoperators(seq::Sequence, β::AbstractVector{<:Real},
    c::Vector{<:Real}=normalize!(ones(size(β)), 1),
    z0::Vector{<:Real}=[0,0,1]
    )::Vector{<:Matrix}
    
    return sqrt.(c).*[unitary(seq, β_k, z0) for β_k in β]
end

function deploy(ψ::Vector{<:Number}, seq::Sequence, n::Int, β::Real, 
    z0::Vector{<:Real}=[0,0,1]; cycle::Int=1)
    dt=seq.idle.t/n
    U0=unitary(Idle(dt),β,z0)
    Un=map(g->unitary(g,β,z0), seq.gates)
    
    t_arr= cycleslice(seq,n)
    N=length(t_arr)

    ψ_arr = Vector{Vector{ComplexF64}}(undef,N*cycle)
    global p=1;
    ψ_arr[p]=ψ

    for k in 1:cycle
        for i in seq.order
            if i==0
                for j in 1:n
                    ψ=U0*ψ
                    p+=1
                    ψ_arr[p] = ψ
                end
            else
                U= sign(i)>0 ? Un[abs(i)] : Un[abs(i)]'
                ψ=U*ψ
                p+=1
                ψ_arr[p] = ψ
            end
        end
    end
    t_arr=vcat([t_arr .* i for i in cycle]...)
    return t_arr, ψ_arr
end


function deploy(ρ::Matrix{ComplexF64}, seq::Sequence, n::Int, β::Vector{<:Real}, 
    c::Vector{<:Real}=normalize!(ones(size(β)), 1), z0::Vector{<:Real}=[0,0,1]; cycle::Int=1)
    
    dt=seq.idle.t/n
    krops0=krausoperators(Idle(dt),β,c,z0)
    kropsn=map(g->krausoperators(g,β,c, z0), seq.gates)
    
    t_arr= cycleslice(seq,n)
    N=length(t_arr)

    ρ_arr = Vector{Matrix{ComplexF64}}(undef,N*cycle)
    global p=1;
    ρ_arr[p]=ρ

    for k in 1:cycle
        for i in seq.order
            if i==0
                for j in 1:n
                    ρ=operate(ρ,krops0)
                    p+=1
                    ρ_arr[p] = ρ
                end
            else
                krops = sign(i)>0 ? kropsn[abs(i)] : kropsn[abs(i)]'
                ρ=operate(ρ,krops)
                p+=1
                ρ_arr[p] = ρ
            end
        end
    end
    
    t_arr=vcat([t_arr .* i for i in cycle]...)
    return t_arr, ρ_arr
end