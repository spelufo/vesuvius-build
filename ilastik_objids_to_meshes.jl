using LinearAlgebra, GeometryBasics, MarchingCubes, FileIO, MeshIO, HDF5


mesh_and_save_hole!(M::Array{UInt32, 3}, i::UInt32, pos::Point3f, filename::String) = begin
  divs = 8
  samples = Float32(divs^3)
  sx, sy, sz = div.(size(M), divs)
  vol = zeros(Float32, (sx, sy, sz))
  for iz = 1:sz, iy = 1:sy, ix = 1:sx
    val = 0f0
    for kz = 1:divs, ky = 1:divs, kx = 1:divs
      inobj = M[divs*(ix-1)+kx, divs*(iy-1)+ky, divs*(iz-1)+kz] == i
      val += Float32(inobj) / samples
    end
    vol[ix, iy, iz] = val - 0.5f0
  end
  mc = MC(vol)
  # mc = MC(Float32(0.5) .- Float32.(M .== i))
  march(mc)

  println("Meshing ($(length(mc.vertices)) vertices)...")
  if length(mc.vertices) < 3
    println("not enough vertices")
  else
    msh = MarchingCubes.makemesh(GeometryBasics, mc)
    msh.position .*= Float32(divs)
    msh.position .+= pos
    save(filename, msh)
  end
  nothing
end

hole_ids_to_meshes(hole_ids_file::String, file_prefix::String, pos::Point3f) = begin
  f = h5open(hole_ids_file)
  M = f["exported_data"][1, :, :, :, 1]
  n = maximum(M)
  close(f)
  for id = 1:n
    println("Building mesh for hole $id / $n ... ")
    mesh_and_save_hole!(M, UInt32(id), pos, "$(file_prefix)$(id).stl")
  end
end
