
//
// The taper is implemented as a scaled linear_extrude: the bottom footprint
// matches the cover rim; the top footprint matches the body outline
// at z = bottom + cover_thickness + spacer_height.
//
// Assembly order (bottom to top):
//   bottom_cover  -> spacer_frame_curved  ->  trackball hollow

// ─── user parameters ─────────────────────────────────────────────────────────

spacer_height   = 4;
wall_thickness  = 3;
cover_thickness = 3;   // must match the cover you printed
ball_diameter   = 55;

spacer_screws = true;

$fa = 4;
$fs = 0.4;

// ─── constants derived from ball_diameter (must match trackball.scad) ────────

ball_clearance   = 1;
bottom_clearance = 4;

ball_radius   = ball_diameter / 2;
recess_radius = ball_radius + ball_clearance;
bottom        = -(recess_radius + bottom_clearance);   // -32.5 for 55 mm

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

// ─── taper parameters ────────────────────────────────────────────────────────
//
// The body tapers inward from its base upward.  Measured the body's XY
// bounding box at the bottom and top of the spacer band from the STL:
//
//   At z = bottom + cover_thickness        (spacer bottom, = cover top):
//     body bbox ≈ 95 × 188 mm, centre ≈ (-4.6, -25.6)
//   At z = bottom + cover_thickness + spacer_height  (spacer top):
//     body bbox ≈ 90 × 140 mm, centre ≈ (-4.6, -25.6)
//   → scale_x ≈ 0.979,  scale_y ≈ 0.880
//
// Apply these as a 2-D scale about the body centre when building the
// top face of the tapered wall.

// Body footprint centre (matches trackball.scad coordinate system)
_body_cx =  -4.6;
_body_cy = -25.6;

// Scale of the body outline at spacer top relative to spacer bottom
_taper_sx = 0.979;
_taper_sy = 0.880;

// ─── STL paths ────────────────────────────────────────────────────────────────

_cover_stl = str("../stl/bottom_cover_", cover_thickness, "mm-", ball_diameter, "mm.stl");

// ─── cover footprint (2-D outer silhouette, holes filled) ────────────────────

module _cover_footprint_2d()
{
    hull()
    projection(cut = true)
    translate([0, 0, 0.5])
    import(_cover_stl);
}

// Cover footprint scaled down to match body at spacer top
module _cover_footprint_top_2d()
{
    translate([_body_cx, _body_cy])
    scale([_taper_sx, _taper_sy])
    translate([-_body_cx, -_body_cy])
    _cover_footprint_2d();
}

// ─── tapered outer wall ───────────────────────────────────────────────────────
//
// Build as: hull(outer-bottom, outer-top) minus hull(inner-bottom, inner-top)
// The hull of two thin slabs gives a linearly tapered frustum matching the body.
//
// _outer_solid() is the full filled frustum, used both for the wall and as a
// clipping volume so stud columns / ribs never protrude outside the taper.

module _outer_solid()
{
    hull()
    {
        translate([0, 0, 0.01])
        linear_extrude(height = 0.01)
        _cover_footprint_2d();

        translate([0, 0, spacer_height - 0.01])
        linear_extrude(height = 0.01)
        _cover_footprint_top_2d();
    }
}

module _tapered_wall()
{
    // Minimum printable wall thickness (mm) — keeps the hollow cutout away
    // from the outer surface at the pointy tips of the footprint.
    min_wall = 0.9;

    difference()
    {
        _outer_solid();

        // Inner void: the hull of the inner bottom and inner top shapes,
        // but intersected with a slightly inset version of the outer solid
        // so no face of the void ever gets closer than min_wall to the
        // outer surface (fixes knife-edge tips flagged by print services).
        intersection()
        {
            hull()
            {
                translate([0, 0, -0.01])
                linear_extrude(height = 0.01)
                offset(-wall_thickness)
                _cover_footprint_2d();

                translate([0, 0, spacer_height + 0.01])
                linear_extrude(height = 0.01)
                offset(-wall_thickness)
                _cover_footprint_top_2d();
            }

            hull()
            {
                translate([0, 0, -0.01])
                linear_extrude(height = 0.01)
                offset(-min_wall)
                _cover_footprint_2d();

                translate([0, 0, spacer_height + 0.01])
                linear_extrude(height = 0.01)
                offset(-min_wall)
                _cover_footprint_top_2d();
            }
        }
    }
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

// ─── spacer_frame_curved ──────────────────────────────────────────────────────

module spacer_frame_curved()
{
    col_d = stud_diameter + wall_thickness * 2;
    rib_z = (spacer_height - wall_thickness) / 2;

    difference()
    {
        union()
        {
            // ── tapered outer wall ────────────────────────────────────────
            _tapered_wall();

            // ── stud columns (clipped to outer taper so they never protrude) ─
            for (loc = stud_locations)
                intersection()
                {
                    translate([loc[0], loc[1], 0])
                    cylinder(d = col_d, h = spacer_height);
                    _outer_solid();
                }

            // ── radial ribs (clipped to outer taper) ──────────────────────
            for (loc = stud_locations)
                intersection()
                {
                    translate([0, 0, rib_z])
                    _rib(loc);
                    _outer_solid();
                }

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

spacer_frame_curved();
