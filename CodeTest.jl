##
using Test
import LinearAlgebra: norm
include("RandLoctions.jl")
include("SpinEnsemble.jl")

M=rand_locs_spherical(1,10,N=1000)

## Test the datatype
@test typeof(M)<:Matrix{Float64}
@test typeof(M)<:AbstractArray{Float64}
@test typeof(rand_bath_dipolar_coefs(100,3))<:Vector{Float64}

## Test the numerical range 
@test minimum(x->abs(norm(x)), eachrow(M))>1
@test maximum(x->abs(norm(x)), eachrow(M))<10

M=rand_locs_cubic(1,10,N=1000)

## Test the datatype
@test typeof(M)<:Matrix{Float64}
@test typeof(M)<:AbstractArray{Float64}
@test typeof(rand_bath_dipolar_coefs(100,3))<:Vector{Float64}

## Test the numerical range 
@test minimum(abs, M)>1
@test maximum(abs, M)<10

## Type pass for all the function
@test typeof(bath_dipolar_coefs(M))<:Vector{Float64}

## 
M=rand_locs(1000,10,4)
@test size(M)==(1000,10)
@test typeof(M)<:Matrix{Float64}
@test maximum(M)<4