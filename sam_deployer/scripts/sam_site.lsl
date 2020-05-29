    /*
                          Fourmilab SAM Site

                           by John Walker

    */


    key owner;                  // UUID of owner
    integer colour;             // Colour index of marker

    integer siteChannel = -982449720;       // Channel for communicating with sites
    string ypres = "Q?+:$$";                // It's pronounced "Wipers"
    string collisionMsg = "IMPACT";         // Message announcing impact to object
    string impactMarker = "Fourmilab Impact Marker";    // Impact marker object from inventory
    integer impactMarkerLife = 30;          // Lifetime of impact markers (seconds)
    string collisionSound = "Balloon_Pop";  // Sound to play for collision

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

    float alpha = 0.5;              // Transparency of faces

    integer site_number;            // Site number
    integer threat_radius;          // Threat radius
    integer threat_altitude;        // Threat altitude
    integer height;                 // Height

    key lastCollision = NULL_KEY;   // Last object we collided with

    default {

        state_entry() {
            owner = llGetOwner();
        }

        on_rez(integer start_param) {
            //  If start_param is zero, this is a simple manual rez
            if (start_param > 0) {
                /*  The start_param is encoded as follows:
                        NNRRRAAHH

                        NN      Site number (1 - 99)
                        RRR     Threat radius, units of 0.1 metres
                        AA      Threat altitude, metres
                        HH      Height of displayed barrier, metres
                */

                site_number = start_param / 10000000;
                threat_radius = (start_param / 10000) % 1000;
                threat_altitude = (start_param / 100) % 100;
                height = start_param % 100;

                if (threat_altitude == 0) {
                    threat_altitude = 4096;
                }

llOwnerSay("Site " + (string) site_number + "  Radius " + (string) threat_radius +
    "  Altitude " + (string) threat_altitude + "  Height " + (string) height);

                //  Set the displayed size to those passed by the deployer

                float diam = (threat_radius / 10.0) * 2;
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_SIZE, < diam, diam, height > ]);

                //  Get terrain level and adjust to sit on terrain

                float terrain = llGround(ZERO_VECTOR);
                float water = llWater(ZERO_VECTOR);
                if (water > terrain) {
                    terrain = water;
                }
                vector pos = llGetPos();
                pos.z = terrain + (height / 2.0);
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_POSITION, pos ]);

                //  Set description to site parameters

                string desc = "\"SAM " + (string) site_number + "\" " +
                    (string) (threat_radius / 10) + "." + (string) (threat_radius % 10) +
                    " " + (string) threat_altitude;
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_DESC, desc ]);

                //  Set colour of faces based upon site number

                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_COLOR, 0, llList2Vector(colours, (site_number / 10) * 2 + 1), alpha,
                      PRIM_COLOR, 1, llList2Vector(colours, (site_number % 10) * 2 + 1), alpha ]);

                llListen(siteChannel, "", "", "");      // Listen for commands from the deployer
            }
        }

        //  The listen event handles commands from the deployer

        listen(integer channel, string name, key id, string message) {
//llOwnerSay("Message channel " + (string) channel + "  name " + name + "  id " + (string) id + "  message " + message);

            //  Message from SAM Site Deployer

            if (channel == siteChannel) {
                if (message == ypres) {
                    llDie();
                }
            }
        }

        //  Collision with object

        collision_start(integer nCol) {
            integer i;

            for (i = 0 ; i < nCol; i++) {
                key whoId = llDetectedKey(i);
//llOwnerSay("whoId " + (string) whoId + "  lastCollision " + (string) lastCollision);
//                if (whoId != lastCollision) {
//                    lastCollision = whoId;
                    string what = llDetectedName(i);
//llOwnerSay("What " + what);
llOwnerSay("Collision with " + what);
                    key ownerK = llDetectedOwner(i);
                    vector where = llDetectedPos(i);

                    /*  Project detected collision position onto surface
                        of threat cylinder.  */

                    vector pos = llGetPos();            // Our position
                    vector ssize = llGetScale();        // Our size
                    pos.z = where.z;                    // Snap height to that of collision
                    vector colvec = where - pos;        // Direction vector from centre to collision
                    vector markerPos = pos + (llVecNorm(colvec) * (ssize.x / 2));
//llOwnerSay("Pos " + (string) pos + "  colvec " + (string) colvec + "  markerPos " + (string) markerPos);

                    /*  Place impact marker on surface of cylinder at
                        collision point.  The colour of the marker, passed
                        in the start parameter, is that of the cylinder
                        surface, derived from the site number.  */

                    llRezObject(impactMarker, markerPos, ZERO_VECTOR,
                        llRotBetween(<0, 0, 1>, markerPos - pos),
                        ((site_number % 10) * 100) + impactMarkerLife);

                    //  Play collision sound
                    llPlaySound(collisionSound, 1);

                    /*  Send a message to the object which collided
                        to inform it of the event.  */

                    list siteLabel = llParseStringKeepNulls(llGetObjectDesc(),
                        [ "\"" ], [ ]);
                    llRegionSayTo(whoId, siteChannel,
                        llList2Json(JSON_ARRAY,
                            [ collisionMsg, markerPos, llList2String(siteLabel, 1) ]));
            }
        }
    }
