    /*
                      Fourmilab Impact Marker

                           by John Walker

        Impact markers are placed by SAM sites, when an object
        collides with them.  The marker is placed at the altitude
        of the collision, tangent to the surface of the cylinder in
        the direction of the detected collision.

        When the SAM site rezzes a target marker, it passes an integer
        start_param coded as CMM as the start_param to the on_rez event
        of this object. This is used to set the colour C (see the table
        below) and time to live, MM, in seconds, of the impact marker,
        with an MM value of zero indicating the target marker is
        immortal.

    */


//    key owner;                  // UUID of owner

    /*  Standard colour names and RGB values.  This is
        based upon the resistor colour code.  */

    list colours = [
        "black",   <0, 0, 0>,                   // 0
        "brown",   <0.3176, 0.149, 0.1529>,     // 1
        "red",     <0.8, 0, 0>,                 // 2
        "orange",  <0.847, 0.451, 0.2784>,      // 3
        "yellow",  <0.902, 0.788, 0.3176>,      // 4
        "green",   <0.3216, 0.5608, 0.3961>,    // 5
        "blue",    <0.00588, 0.3176, 0.5647>,   // 6
        "violet",  <0.4118, 0.4039, 0.8078>,    // 7
        "grey",    <0.4902, 0.4902, 0.4902>,    // 8
        "white",   <1, 1, 1>                    // 9

//      "silver",  <0.749, 0.745, 0.749>,       // 10%
//      "gold",    <0.7529, 0.5137, 0.1529>     // 5%
    ];

    default {

//        state_entry() {
//            owner = llGetOwner();
//        }

        on_rez(integer start_param) {
            /*  The start_param is encoded as follows:
                        CMM

                        MM = Time to live, 0 - 99 seconds (0 = immortal)
                        C  = Colour index as given above
            */
//llOwnerSay("CMM " + (string) start_param);
            integer time_to_live = start_param % 100;
            integer colour = (start_param / 100) % 10;
            llSetLinkPrimitiveParamsFast(LINK_THIS,
                [ PRIM_COLOR, ALL_SIDES,
                    llList2Vector(colours, (colour * 2) + 1), 1 ]);

            if (start_param > 0) {
                llSetTimerEvent((float) time_to_live);   // Start self-deletion timer
            }
        }

        //  The timer event deletes impact markers after a decent interval

        timer() {
            llDie();                    // I'm out of here
        }
    }
