//////////////////////////////
// Cookie Cutter Generator  //
//////////////////////////////

// ====== INPUT FILE ======
art_file = "niceCookie";   // single SVG with outline + inner details
//outline_file = str(art_file, "_outline.svg");
outline_file = "niceCookie_outline.svg";
detail_file = str(art_file, "_detail.svg");
RENDER_MODE = "stamp"; // options are "cutter" to create the cookie cutter or "stamp" to create the detailed stamp

// Direct imports for debugging:
module OUTLINE() import(outline_file, center=true);
module DETAIL()  import(detail_file, center=true);
module NONSENSE() import(art_file, center=true, layer="non-existant-layer");

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
scale_xy = 1.0;  // mm per SVG unit

// ====== CUTTER GEOMETRY ======
cutter_height      = 16;   // wall height
cutting_edge_h     = 2;    // bevel height at bottom

wall_thickness     = 0.8;  // main wall thickness
inner_shrink       = 0.2;  // inset for inner wall

outer_lip_width    = 1.2;  // extra outer “brim” for strength
outer_lip_height   = 8;    // height of that lip

// ====== STAMP GEOMETRY ======
make_stamp         = true;

stamp_base_thick   = 3;
stamp_detail_h     = 1.2;
stamp_inset        = 1;    // shrink stamp perimeter inside cutter
stamp_detail       = 1.5;
$fn = 80;
inset_outline = 0.2;   // shrink detail boundary so it stays off the cutter wall
inset_detail  = 0.2;   // shrink the subtracted black regions slightly


//////////////////////////////
//   SHAPE HELPERS         //
//////////////////////////////

// Full artwork as 2D
module art_2d() {
    scale([scale_xy, scale_xy, 1])
        import(outline_file, center = true);
}

// 2D ring used for cutter wall
module cutter_wall_2d() {
    difference() {
        // outer edge including lip width
        offset(delta = wall_thickness + outer_lip_width)
            art_2d();

        // inner edge
        offset(delta = -inner_shrink)
            art_2d();
    }
}

// Lip-only region
module cutter_lip_2d() {
    difference() {
        offset(delta = wall_thickness + outer_lip_width)
            art_2d();
        offset(delta = wall_thickness)
            art_2d();
    }
}

// Core wall (no lip)
module cutter_core_wall_2d() {
    difference() {
        offset(delta = wall_thickness)
            art_2d();
        offset(delta = -inner_shrink)
            art_2d();
    }
}

//////////////////////////////
//    3D CUTTER BODY        //
//////////////////////////////

module cookie_cutter() {

    // 1) main wall
    linear_extrude(height = cutter_height)
        cutter_core_wall_2d();

    // 2) outer lip for strength
    linear_extrude(height = outer_lip_height)
        cutter_lip_2d();

    // 3) beveled cutting edge
    if (cutting_edge_h > 0) {
        hull() {
            linear_extrude(height = 0.1)
                cutter_core_wall_2d();

            translate([0, 0, cutting_edge_h])
                linear_extrude(height = 0.1)
                    offset(delta = -0.2)
                        cutter_core_wall_2d();
        }
    }
}

//////////////////////////////
//      3D STAMP PIECE      //
//////////////////////////////
module stamp_detail_2d(inset_outline=0.2, inset_detail=0.2) {
    // Raised = (cookie interior) - (black/detail regions)
    difference() {
        offset(delta = -inset_outline) OUTLINE();
        offset(delta = -inset_detail)  DETAIL();
    }
}
// (B) If DETAIL is the interior islands:

module WHITE_AREAS_2D() {
  intersection() {
    offset(delta=-0.2) OUTLINE();
    offset(delta=-0.2) DETAIL();
  }
}

// (A) If DETAIL is the black silhouette blob, use this instead:
/*
module WHITE_AREAS_2D() {
   difference() {
     offset(delta=-0.2) OUTLINE();
     offset(delta=-0.2) DETAIL();
   }
 }
*/
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
    offset(delta=-0.2)
      OUTLINE();

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
//translate([-80, 0, 0]) cookie_cutter();
//if (make_stamp) translate([80, 0, 0]) cookie_stamp();
