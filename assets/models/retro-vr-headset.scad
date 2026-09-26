// Reduced wireframe derivative of the Meta Quest 3 mesh by Elin (@ElinHohler), CC BY 4.0.
// Source: https://sketchfab.com/3d-models/meta-quest-3-65a813833dc04eeeb7d33bdca58c184c
// The source model is Y-up; its vertical top-to-bottom axis is Y.
// $t rotates around Y while the visor faces toward +Z.
rotate([0, 360*$t+45, 0])
  scale(3.4)
    translate([0.00007637, -0.00083683, 0.00326583])
      import("vr-headset-wireframe.stl", convexity=10);
