// Reduced wireframe derivative of the Meta Touch Plus left controller by AVILOV, CC BY 4.0.
// Source model and license information: THIRD_PARTY_NOTICES.md.
// Rotate around the vertical Y axis.
rotate([0, 360*$t+90, 0])
  rotate([-90, 0, 0])
  scale(3.4)
    translate([-0.00001595, -0.00001332, -0.00002330])
      import("quest3-controller-left-wireframe.stl", convexity=10);
