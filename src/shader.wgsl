@group(0) @binding(0) var<storage, read_write> array_a : array<f32>;

@compute @workgroup_size(64, 1)
fn main(@builtin(global_invocation_id) global_id : vec3u) {
  // Guard against out-of-bounds work group sizes
  if (global_id.x >= 128) {
    return;
  }

  let index = global_id.x;
  array_a[index] = f32(index) + 1000.0;
}
