    /*
                          Fourmilab SAM Site

                           by John Walker

    */


    key owner;                              // UUID of owner

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

    //  max  --  Maximum of two float arguments

    float max(float a, float b) {
        if (a > b) {
            return a;
        } else {
            return b;
        }
    }

    //  ef  --  Edit floats in string to parsimonious representation

    string ef(string s) {
        integer p = llStringLength(s) - 1;

        while (p >= 0) {
            //  Ignore non-digits after numbers
            while ((p >= 0) &&
                   (llSubStringIndex("0123456789", llGetSubString(s, p, p)) < 0)) {
                p--;
            }
            //  Verify we have a sequence of digits and one decimal point
            integer o = p - 1;
            integer digits = 1;
            integer decimals = 0;
            while ((o >= 0) &&
                   (llSubStringIndex("0123456789.", llGetSubString(s, o, o)) >= 0)) {
                o--;
                if (llGetSubString(s, o, o) == ".") {
                    decimals++;
                } else {
                    digits++;
                }
            }
            if ((digits > 1) && (decimals == 1)) {
                //  Elide trailing zeroes
                while ((p >= 0) && (llGetSubString(s, p, p) == "0")) {
                    s = llDeleteSubString(s, p, p);
                    p--;
                }
                //  If we've deleted all the way to the decimal point, remove it
                if ((p >= 0) && (llGetSubString(s, p, p) == ".")) {
                    s = llDeleteSubString(s, p, p);
                    p--;
                }
                //  Done with this number.  Skip to next non digit or decimal
                while ((p >= 0) &&
                       (llSubStringIndex("0123456789.", llGetSubString(s, p, p)) >= 0)) {
                    p--;
                }
            } else {
                //  This is not a floating point number
                p = o;
            }
        }
        return s;
    }

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

//llOwnerSay("Site " + (string) site_number + "  Radius " + (string) threat_radius +
//    "  Altitude " + (string) threat_altitude + "  Height " + (string) height);

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

                /*  Now cast a ray downward from the site's position
                    and see if we have an obstacle to avoid.  If so,
                    place the SAM site on top of the closest obstacle.
                    If we detect nothing, use the higher of the ground
                    and water levels below us.  This is particularly
                    important when the user is placing sites on an
                    object above ground level.  */

                vector where = pos + <0, 0, -((height / 2) + 0.1)>;
                list rcr = llCastRay(where,
                    pos + (< 0, 0, -height >),
                    [ RC_REJECT_TYPES, RC_REJECT_AGENTS, RC_MAX_HITS, 5 ]);
                integer rcstat = llList2Integer(rcr, -1);
                float conflictAlt = 0;
                integer nhits = 0;
                if (rcstat > 0) {
                    integer i;
                    for (i = 0; i < rcstat; i++) {
                        key what = llList2Key(rcr, i * 2);
                        vector rhit = llList2Vector(rcr, (i * 2) + 1);
                        string which = "Ground";
                        if (what != NULL_KEY) {
                            which = llKey2Name(what);
                        }
//llOwnerSay("Detected " + which + " at " + (string) rhit +
//           ", range " + (string) llVecDist(pos, rhit));
                        conflictAlt = max(conflictAlt, rhit.z);
                        nhits++;
                    }
                }

                float zpos = max(conflictAlt, terrain);
//llOwnerSay("pos " + (string) pos + "  terrain " + (string) terrain + "  water " + (string) //water + "  height " + (string) height + "  zpos " + (string) zpos);
                pos.z = zpos + (height / 2.0);
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

            //  Message from SAM Site Deployer

            if (channel == siteChannel) {
                if (message == ypres) {
                    llDie();
                } else if (message == "LIST") {
                    string ccode = llList2String(colours, (site_number / 10) * 2) + "/" +
                                   llList2String(colours, (site_number % 10) * 2);

                    llOwnerSay("SAM site " + (string) site_number +
                               " (" + ccode + ")" +
                               "  Radius " + ef((string) (threat_radius / 10.0)) +
                               "  Altitude " + (string) threat_altitude +
                               "  Height " + (string) height +
                               "  Position: " + ef((string) llGetPos()));
                }
            }
        }

        //  Collision with object

        collision_start(integer nCol) {
            integer i;

            for (i = 0 ; i < nCol; i++) {
                key whoId = llDetectedKey(i);
                    string what = llDetectedName(i);
llOwnerSay("Collision with " + what);
                    vector where = llDetectedPos(i);

                    /*  Project detected collision position onto surface
                        of threat cylinder.  */

                    vector pos = llGetPos();            // Our position
                    vector ssize = llGetScale();        // Our size
                    pos.z = where.z;                    // Snap height to that of collision
                    vector colvec = where - pos;        // Direction vector from centre to collision
                    vector markerPos = pos + (llVecNorm(colvec) * (ssize.x / 2));

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
