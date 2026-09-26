// Reduced wireframe derivative of the Meta Touch Plus right controller by AVILOV, CC BY 4.0.
// Source model and license information: THIRD_PARTY_NOTICES.md.
// Rotate around the vertical Y axis.
rotate([0, 360*$t+90, 0])
  rotate([-90, 0, 0])
  scale(3.4)
    translate([0.00001599, -0.00000615, -0.00002426])
      import("quest3-controller-right-wireframe.stl", convexity=10);
