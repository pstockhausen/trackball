
//
// spacer_frame_flat.scad
//
// A simple flat-walled spacer ring: takes the exact outer footprint of the
// bottom cover and extrudes it straight upward (no taper, no curve).
//
// Bottom face: snaps onto the bottom cover top rim (same footprint).
// Top face   : presses flush against the underside of the hollow shell.
//
// Assembly order (bottom to top):
//   bottom_cover  →  spacer_frame_flat  →  trackball hollow

// ─── user parameters ─────────────────────────────────────────────────────────

spacer_height   = 4;
wall_thickness  = 3;
cover_thickness = 3;
ball_diameter   = 55;

spacer_screws = true;

$fa = 4;
$fs = 0.4;

// ─── constants (must match trackball.scad) ────────────────────────────────────

ball_clearance   = 1;
bottom_clearance = 4;

ball_radius   = ball_diameter / 2;
recess_radius = ball_radius + ball_clearance;
bottom        = -(recess_radius + bottom_clearance);

stud_diameter = 5;
stud_height   = 2;

stud_locations = [
    [0,   -80],
    [27,  -55],
    [33,  -20],
    [-4,   23],
    [-45,  15],
    [-39, -27],
];

// ─── STL path ────────────────────────────────────────────────────────────────

_cover_stl = str("../stl/bottom_cover_", cover_thickness, "mm-", ball_diameter, "mm.stl");

// ─── cover footprint (2-D outer silhouette, holes filled) ────────────────────

module _cover_footprint_2d()
{
    hull()
    projection(cut = true)
    translate([0, 0, 0.5])
    import(_cover_stl);
}

// ─── stud / stud-hole modules ─────────────────────────────────────────────────

module _stud()
{
    translate([0, 0, -0.01])
    cylinder(d = stud_diameter, h = stud_height + 0.01);
}

module _stud_hole()
{
    hole_sides = 8;
    fudge = 1 / cos(180 / hole_sides);
    r = (stud_diameter / 2) * fudge;

    translate([0, 0, -0.01])
    {
        linear_extrude(height = stud_height + 0.02)
        circle(r = r, $fn = hole_sides);

        translate([0, 0, stud_height])
        linear_extrude(height = stud_diameter / 2, scale = 0)
        circle(r = r, $fn = hole_sides);
    }

    if (spacer_screws)
        cylinder(d = 3, h = 6);
}

// ─── radial rib ───────────────────────────────────────────────────────────────
//
// A flat arm connecting each stud column back to the outer wall ring.
// Clipped to the cover footprint so it never protrudes outside.

module _rib(loc)
{
    rib_w = wall_thickness;
    rib_h = wall_thickness;
    col_r = (stud_diameter + wall_thickness * 2) / 2;
    angle = atan2(loc[1], loc[0]);

    intersection()
    {
        linear_extrude(height = rib_h)
        _cover_footprint_2d();

        difference()
        {
            linear_extrude(height = rib_h)
            translate([loc[0], loc[1]])
            rotate([0, 0, angle])
            translate([0, -rib_w / 2])
            square([200, rib_w]);

            translate([loc[0], loc[1]])
            cylinder(r = col_r - 0.01, h = rib_h + 0.02);
        }
    }
}

// ─── spacer_frame_flat ────────────────────────────────────────────────────────

module spacer_frame_flat()
{
    col_d = stud_diameter + wall_thickness * 2;
    rib_z = (spacer_height - wall_thickness) / 2;

    difference()
    {
        union()
        {
            // ── straight vertical wall ring ───────────────────────────────
            linear_extrude(height = spacer_height)
            difference()
            {
                _cover_footprint_2d();
                offset(-wall_thickness)
                _cover_footprint_2d();
            }

            // ── stud columns clipped to footprint ─────────────────────────
            for (loc = stud_locations)
                intersection()
                {
                    translate([loc[0], loc[1], 0])
                    cylinder(d = col_d, h = spacer_height);

                    linear_extrude(height = spacer_height)
                    _cover_footprint_2d();
                }

            // ── radial ribs at mid-height ─────────────────────────────────
            for (loc = stud_locations)
                translate([0, 0, rib_z])
                _rib(loc);

            // ── top studs ─────────────────────────────────────────────────
            for (loc = stud_locations)
                translate([loc[0], loc[1], spacer_height])
                _stud();
        }

        // ── bottom stud holes ─────────────────────────────────────────────
        for (loc = stud_locations)
            translate([loc[0], loc[1], 0])
            _stud_hole();

        // ── M3 pass-through holes ─────────────────────────────────────────
        if (spacer_screws)
            for (loc = stud_locations)
                translate([loc[0], loc[1], -0.01])
                cylinder(d = 3, h = spacer_height + 0.02);
    }
}

spacer_frame_flat();
