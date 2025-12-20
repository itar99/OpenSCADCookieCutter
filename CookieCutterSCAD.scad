//////////////////////////////
// Cookie Cutter Generator  //
//////////////////////////////

// ====== INPUT FILE ======
art_file = "Nice";   // single SVG with outline + inner details
//outline_file = str(art_file, "_outline.svg");
outline_file = str(art_file, "_outline.svg");
detail_file = str(art_file, "_detail.svg");
RENDER_MODE = "cutter"; // options are "cutter" to create the cookie cutter or "stamp" to create the detailed stamp

// Direct imports for debugging:
module OUTLINE() import(outline_file, center=true, dpi=SVG_DPI);
module DETAIL()  import(detail_file, center=true, dpi=SVG_DPI);

// --- SCALED imports (used for modeling) ---
module OUTLINE_2D() {
    scale([scale_xy, scale_xy, 1])
        import(outline_file, center=true, dpi=SVG_DPI);
}

module DETAIL_2D() {
    scale([scale_xy, scale_xy, 1])
        import(detail_file, center=true, dpi=SVG_DPI);
}

// size information
ART_W_U = 90;
ART_H_U = 90;
echo("ART_W_U:", ART_W_U);
echo("ART_H_U:", ART_H_U);

// Target smallest dimension (mm) after scaling
target_min_mm = 90;

// --- Stamp handle settings ---
STAMP_HANDLE       = true;
handle_total_h_mm  = 22;
handle_waist_r_mm  = 9;    // narrow middle
handle_cap_r_mm    = 18;   // flared top radius (grip!)
handle_cap_h_mm    = 6;    // thickness of the flared cap
handle_base_r_mm   = 16;   // base flare for strength
handle_base_h_mm   = 4;    // base thickness
handle_fillet_mm   = 2;    // softens transitions (approx)

// ====== SCALE / SIZE ======
//scale_xy = 1.0;  // mm per SVG unit
SVG_DPI = 96;                 // treat SVG units as px at 96 dpi
MM_PER_U = 25.4 / SVG_DPI;    // mm per SVG unit (px)
scale_xy = target_min_mm / (min2(ART_W_U, ART_H_U) * MM_PER_U);


// ====== CUTTER GEOMETRY ======
cutter_height      = 16;   // wall height

wall_thickness     = 2;  // main wall thickness
inner_shrink       = 0.6;  // inset for inner wall

outer_lip_width    = 3;  // extra outer “brim” for strength
outer_lip_height   = 4;    // height of that lip

bevel_band_h = 3;     // height of beveled zone at top
edge_width   = 0.1;   // outer wall thickness at cutting edge
bevel_steps = 10;  // smoothness (8–16 is fine)

// ====== STAMP GEOMETRY ======
$fn = 80;
stamp_clearance = 0.4; // mm, tweak for printer tolerance

//////////////////////////////
//   SHAPE HELPERS         //
//////////////////////////////

function min2(a,b) = (a < b) ? a : b;
// mm per SVG unit


// Full artwork as 2D
module art_2d() {
    scale([scale_xy, scale_xy, 1])
        import(outline_file, center = true);
}

// Lip-only region
module cutter_lip_2d() {
    difference() {
        offset(delta = wall_thickness + outer_lip_width)
            OUTLINE_2D();
        offset(delta = wall_thickness)
            OUTLINE_2D();
    }
}

// Core wall (no lip)
module cutter_core_wall_2d() {
    difference() {
        offset(delta = wall_thickness)
            OUTLINE_2D();
        offset(delta = -inner_shrink)
            OUTLINE_2D();
    }
}

module cutter_ring_2d(outer) {
    difference() {
        offset(delta = outer) OUTLINE_2D();
        offset(delta = -inner_shrink) OUTLINE_2D();
    }
}

module cutter_top_bevel_3d() {

    step_h = bevel_band_h / bevel_steps;

    for (i = [0 : bevel_steps-1]) {
        t = (i + 1) / bevel_steps;   // 0 → 1 as we go UP
        outer_i = wall_thickness - (wall_thickness - edge_width) * t;

        translate([0, 0, (cutter_height - bevel_band_h) + i * step_h])
            linear_extrude(height = step_h + 0.001)
                cutter_ring_2d(outer_i);
    }
}

//////////////////////////////
//    3D CUTTER BODY        //
//////////////////////////////

module cookie_cutter() {

    // 1) main wall
    //linear_extrude(height = cutter_height)
    //    cutter_core_wall_2d();
    // 1) straight wall up to bevel zone
    linear_extrude(height = cutter_height - bevel_band_h)
        cutter_core_wall_2d();

    // 2) beveled cutting edge at the TOP
    cutter_top_bevel_3d();
    //cutter_taper_band_3d();

    // reinforcement lip above bevel
    translate([0,0,0])
        linear_extrude(height = outer_lip_height)
            cutter_lip_2d();
            
            
}

//////////////////////////////
//      3D STAMP PIECE      //
//////////////////////////////
module WHITE_AREAS_2D() {
  intersection() {
    offset(delta=-0.2) OUTLINE_2D();
    offset(delta=-0.2) DETAIL_2D();
  }
}

module stamp_handle() {
    // Base flare (strong attachment)
    cylinder(h = handle_base_h_mm, r = handle_base_r_mm);

    // Waist (comfortable pinch)
    translate([0,0,handle_base_h_mm])
        cylinder(h = handle_total_h_mm - handle_base_h_mm - handle_cap_h_mm,
                 r = handle_waist_r_mm);

    // Flared cap (the grip)
    translate([0,0,handle_total_h_mm - handle_cap_h_mm])
        cylinder(h = handle_cap_h_mm, r1 = handle_waist_r_mm, r2 = handle_cap_r_mm);

    // Rounded rim on top (cheap and cheerful)
    translate([0,0,handle_total_h_mm - handle_fillet_mm])
        intersection() {
            sphere(r = handle_cap_r_mm);
            // keep only upper-ish part of the sphere to make a dome
            translate([-2*handle_cap_r_mm, -2*handle_cap_r_mm, 0])
                cube([4*handle_cap_r_mm, 4*handle_cap_r_mm, 2*handle_cap_r_mm]);
        }
}

module cookie_stamp() {
  

  // base that fits inside cutter
  base_thick = 3;
  raise_h    = 1.2;
  color("lightgray")
  linear_extrude(height=base_thick)
    offset(delta=-stamp_clearance)
      OUTLINE_2D();

  // raised detail
  color("red")
  translate([0,0,base_thick])
    linear_extrude(height=raise_h)
      WHITE_AREAS_2D();
    
  // Handle on top (centered)
  if (STAMP_HANDLE)
    translate([0,0,raise_h / 2])
        mirror([0, 0, 1])
            stamp_handle();


}

//////////////////////////////
//      TOP-LEVEL CALL      //
//////////////////////////////

// Export cutter:
// cookie_cutter();

// Export stamp:
// if (make_stamp) cookie_stamp();

// Preview both:
if(RENDER_MODE == "cutter") cookie_cutter();
if (RENDER_MODE == "stamp") cookie_stamp();    

