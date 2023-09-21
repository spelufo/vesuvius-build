# Follows Steger's paper and Ghassaei's virtual-unfolding.

using StaticArrays, LinearAlgebra, JLD
using Images, TiffImages, ImageFiltering, ImageView


const Vol = Array{Float32,3}

load_cell(filename::String) =
  convert(Vol, load(filename))

if !@isdefined V
  println("Loading...")
  V = load_cell("../data/full-scrolls/Scroll1.volpkg/volume_grids/20230205180739/cell_yxz_006_008_004.tif")
end


# using SpecialFunctions: erf
# ϕ(σ, x) = (sqrt(π/2) * (erf(x * σ)/sqrt(2) + 1)) / σ
g0(σ::Float32, x::Float32) = exp(-(x/σ)^2/2.0) / σ / sqrt(2π)
g1(σ::Float32, x::Float32) = -x * exp(-(x/σ)^2/2.0) / σ^3 / sqrt(2π)
g2(σ::Float32, x::Float32) = (x^2 - σ^2) * exp(-(x/σ)^2/2.0) / σ^5 / sqrt(2π)

steger_kernels(w::Float32) = begin
  σ = w/sqrt(12f0)
  MAX_SIZE_MASK_0 = 3.09023230616781f0  # Size for Gaussian mask.
  MAX_SIZE_MASK_1 = 3.46087178201605f0  # Size for 1st derivative mask.
  MAX_SIZE_MASK_2 = 3.82922419517181f0  # Size for 2nd derivative mask.
  dim = max(ceil(MAX_SIZE_MASK_0 * σ), ceil(MAX_SIZE_MASK_1 * σ), ceil(MAX_SIZE_MASK_2 * σ))
  G0 = Float32[g0(σ, Float32(x - dim)) for x in 0:2*dim]
  G1 = Float32[g1(σ, Float32(x - dim)) for x in 0:2*dim]
  G2 = Float32[g2(σ, Float32(x - dim)) for x in 0:2*dim]
  G0, G1, G2
end

# Do this in a function and save it so that we don't hold onto the result,
# because at  500M each we quickly run out of memory and the OS kills us.
build_derivative!(V::Vol, k1::Vector{Float32}, k2::Vector{Float32}, k3::Vector{Float32}, name::String) = begin
  G = imfilter(V, kernelfactors((k1, k2, k3)))::Vol
  jldopen("data/G.jld", isfile("data/G.jld") ? "r+" : "w") do f
    f[name] = G
  end
end

# const w = 7f0  # Thickness.
const w = 15f0  # Thickness.
const G0, G1, G2 = steger_kernels(w)


# 1. Derivatives ###############################################################

build_derivatives!(V::Array{Float32,3}) = begin
  println("Building first derivatives...")
  @time build_derivative!(V, G1, G0, G0, "GY")
  @time build_derivative!(V, G0, G1, G0, "GX")
  @time build_derivative!(V, G0, G0, G1, "GZ")
  GC.gc()

  println("Building second derivatives...")
  @time build_derivative!(V, G0, G1, G1, "GZX")
  @time build_derivative!(V, G1, G0, G1, "GYZ")
  @time build_derivative!(V, G1, G1, G0, "GXY")
  GC.gc()
  @time build_derivative!(V, G2, G0, G0, "GYY")
  @time build_derivative!(V, G0, G2, G0, "GXX")
  @time build_derivative!(V, G0, G0, G2, "GZZ")
  GC.gc()
end

# build_derivatives!(V)
# Building first derivatives...
#   3.340213 seconds (98.75 k allocations: 1016.523 MiB, 1.12% gc time, 54.92% compilation time)
#   3.828404 seconds (43.74 k allocations: 1013.721 MiB, 0.35% gc time, 4.67% compilation time: 7% of which was recompilation)
#   4.360553 seconds (15.63 k allocations: 1011.783 MiB, 0.45% gc time, 0.56% compilation time)
# Building second derivatives...
#   3.758675 seconds (15.13 k allocations: 1011.758 MiB, 0.02% gc time)
#   6.014720 seconds (15.13 k allocations: 1011.758 MiB, 0.03% gc time)
#   6.138643 seconds (15.13 k allocations: 1011.758 MiB, 0.57% gc time)
#   2.633229 seconds (15.13 k allocations: 1011.758 MiB, 0.03% gc time)
#   4.580047 seconds (15.13 k allocations: 1011.758 MiB, 0.03% gc time)
#   5.104660 seconds (15.13 k allocations: 1011.758 MiB, 0.05% gc time)


# 2. Normals ###################################################################

build_normals!(GXX::Vol, GYY::Vol, GZZ::Vol, GXY::Vol, GYZ::Vol, GZX::Vol) = begin
  N = Array{Float32, 4}(undef, (3, 500, 500, 500))  # 1.5G
  r = Array{Float32, 3}(undef, (500, 500, 500))
  Threads.@threads for z = 1:500
    H = zeros(Float32, 3, 3)
    for x = 1:500, y = 1:500
      H[1,1] = GXX[y, x, z]
      H[2,2] = GYY[y, x, z]
      H[3,3] = GZZ[y, x, z]
      H[1,2] = H[2,1] = GXY[y, x, z]
      H[2,3] = H[3,2] = GYZ[y, x, z]
      H[3,1] = H[1,3] = GZX[y, x, z]
      e = eigen(H)
      i = argmax(e.values)
      N[:, y, x, z] = e.vectors[:, i]
      r[y, x, z] = e.values[i]
    end
  end
  @save "data/N.jld" N r
end

# println("Loading derivatives...")
# @time @load "data/G.jld" GXX GYY GZZ GXY GYZ GZX  # 6 x 500M = 3G
# 4.150267 seconds (278.91 k allocations: 2.812 GiB, 1.14% gc time, 8.66% compilation time)
# println("Building normals...")
# @time build_normals!(GXX, GYY, GZZ, GXY, GYZ, GZX)
# Building normals...
# 176.917448 seconds (1.50 G allocations: 177.048 GiB, 12.34% gc time, 8.51% compilation time)

@inline clamp01(x::Float32) = clamp(x, 0f0, 1f0)
@inline clampRGB(c::RGB{Float32}) = RGB{Float32}(clamp01(c.r),clamp01(c.g),clamp01(c.b))

make_normals_gif(N::Array{Float32,4}, r::Array{Float32,3}, frames::Int) = begin
  anim = zeros(RGB{N0f8}, size(r, 1), size(r, 3), frames)
  for x = 1:frames
    rx = @view r[:,div(size(r,2), frames)*x,:]
    Nx = @view N[:, :,div(size(r,2), frames)*x,:]
    NRGBx = colorview(RGB, 30f0 .* abs.(Nx))
    anim[:, :, x] =  RGB{N0f8}.(clampRGB.(abs.(rx) .* NRGBx))
  end
  save("N.gif", anim, fps=24)
end

# @load "data/N.jld" N r
# make_normals_gif(N, r, 50)


# 3. Relaxed normals ###########################################################

build_normals_relaxed_step!(
  N::Array{Float32, 4}, r::Array{Float32, 3}, Nr::Array{Float32, 4}, rr::Array{Float32, 3},
  GXX::Vol, GYY::Vol, GZZ::Vol, GXY::Vol, GYZ::Vol, GZX::Vol
) = begin
  Threads.@threads for z = 2:499
    @inbounds for x = 2:499
      @simd for y = 2:499
        # Write it out, to avoid allocation...
        Nc  = SVector{3,Float32}(N[1, y, x, z],   N[2, y, x, z],   N[3, y, x, z]);   rc  = abs(r[y, x, z])
        Nyp = SVector{3,Float32}(N[1, y+1, x, z], N[2, y+1, x, z], N[3, y+1, x, z]); ryp = abs(r[y+1, x, z])
        Nyn = SVector{3,Float32}(N[1, y-1, x, z], N[2, y-1, x, z], N[3, y-1, x, z]); ryn = abs(r[y-1, x, z])
        Nxp = SVector{3,Float32}(N[1, y, x+1, z], N[2, y, x+1, z], N[3, y, x+1, z]); rxp = abs(r[y, x+1, z])
        Nxn = SVector{3,Float32}(N[1, y, x-1, z], N[2, y, x-1, z], N[3, y, x-1, z]); rxn = abs(r[y, x-1, z])
        Nzp = SVector{3,Float32}(N[1, y, x, z+1], N[2, y, x, z+1], N[3, y, x, z+1]); rzp = abs(r[y, x, z+1])
        Nzn = SVector{3,Float32}(N[1, y, x, z-1], N[2, y, x, z-1], N[3, y, x, z-1]); rzn = abs(r[y, x, z-1])

        Navg = normalize(rc*Nc + ryp*Nyp + ryn*Nyn + rxp*Nxp + rxn*Nxn + rzp*Nzp + rzn*Nzn)
        Nr[:, y, x, z] = Navg
        rr[y, x, z] = GXX[y,x,z]*Navg[1]^2 + GYY[y,x,z]*Navg[2]^2 + GZZ[y,x,z]*Navg[3]^2 +
          2.0f0 * (GXY[y,x,z]*Navg[1]*Navg[2] + GYZ[y,x,z]*Navg[2]*Navg[3] + GZX[y,x,z]*Navg[3]*Navg[1])
      end
    end
  end
  nothing
end

build_normals_relaxed!(N::Array{Float32,4}, r::Array{Float32,3}, GXX::Vol, GYY::Vol, GZZ::Vol, GXY::Vol, GYZ::Vol, GZX::Vol) = begin
  Nr::Array{Float32,4} = Array{Float32,4}(undef, size(N))
  rr::Array{Float32,3} = Array{Float32,3}(undef, size(r))
  iters = 40
  for i = 1:iters
    build_normals_relaxed_step!(N, r, Nr, rr, GXX, GYY, GZZ, GXY, GYZ, GZX)
    N, Nr = Nr, N
  end
  @save "data/Nr.jld" Nr rr
end

# if !@isdefined GXX
#   println("Loading derivatives...")
#   @time @load "data/G.jld" GXX GYY GZZ GXY GYZ GZX  # 6 x 500M = 3G
# end
# if !@isdefined r
#   println("Loading normals and responses...")
#   @load "data/N.jld" N r
# end

# println("Building relaxed normals...")
# @time build_normals_relaxed!(N, r, GXX, GYY, GZZ, GXY, GYZ, GZX)
# 44.390414 seconds (212.52 k allocations: 1.876 GiB, 0.03% gc time, 5.38% compilation time)


# 3. Points ####################################################################

@inline interpolate_trilinear(V::Vol, p::SVector{3, Float32}) = begin
  q = p .+ 0.5f0
  i = floor.(q)
  λ = q - i
  x, y, z = Int.(i)

  # https://en.wikipedia.org/wiki/Trilinear_interpolation
  c00 = λ[2] * V[y, x, z]         + (1f0 - λ[2]) * V[y + 1, x, z]
  c01 = λ[2] * V[y, x, z + 1]     + (1f0 - λ[2]) * V[y + 1, x, z + 1]
  c10 = λ[2] * V[y, x + 1, z]     + (1f0 - λ[2]) * V[y + 1, x + 1, z]
  c11 = λ[2] * V[y, x + 1, z + 1] + (1f0 - λ[2]) * V[y + 1, x + 1, z]
  c0 = λ[1] * c00  + (1f0 - λ[1]) * c10
  c1 = λ[1] * c01  + (1f0 - λ[1]) * c11
  c = λ[3] * c0 + (1f0 - λ[3]) * c1
  c
end

build_points!(V::Vol, N::Array{Float32, 4}) = begin
  P = Array{Float32, 4}(undef, (3, 500, 500, 500))  # 1.5G
  kdim = div(size(G1, 1), 2)
  Threads.@threads for z = 1+kdim:500-kdim-1
    for x = 1+kdim:500-kdim-1, y = 1+kdim:500-kdim-1
      if V[y, x, z] < 0.6
        continue
      end
      n = SVector{3, Float32}(N[1, y, x, z], N[2, y, x, z], N[3, y, x, z])
      if abs(n[2]) < 0.5f0  # dot product with ŷ
        continue
      end
      p = SVector{3, Float32}(x - 0.5f0, y - 0.5f0, z - 0.5f0)
      r1 = 0.0f0
      r2 = 0.0f0
      for j = -kdim:kdim
        val = interpolate_trilinear(V, p + j*n)
        r1 += G1[kdim+j+1] * val
        r2 += G2[kdim+j+1] * val
      end
      if r2 > 0f0
        continue
      end
      t = -r1 / r2
      d = t * n
      if abs(d[1] > 0.5f0) || abs(d[2] > 0.5f0) || abs(d[3] > 0.5f0)
        continue
      end
      P[:, y, x, z] = p + d
    end
  end
  @save "data/Py.jld" P
end

# if !@isdefined Nr
#   println("Loading relaxed normals...")
#   @load "data/Nr.jld" Nr
# end
# println("Building points...")
# @time build_points!(V, Nr)


make_points_gif(P::Array{Float32,4}, frames::Int) = begin
  anim = zeros(Gray{N0f8}, size(r, 1), size(r, 3), frames)
  for x = 1:frames
    Px = @view P[:, :,div(size(r,2), frames)*x,:]
    anim[:, :, x] = @. Gray{N0f8}(Px[1, :, :] != 0f0 || Px[2,:,:] != 0f0 || Px[3,:,:] !=  0f0)
  end
  save("P.gif", anim, fps=12)
end

# if !@isdefined P
#   println("Loading points...")
#   @load "data/P.jld" P
# end
# println("Making points gif...")
# @time make_points_gif(P, 250)
