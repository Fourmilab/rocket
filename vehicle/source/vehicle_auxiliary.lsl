   /*

               Vehicle Auxiliary Functions

                    by John Walker

    */

    //  Heartbeat counters

    float hbTimeout = 2;            // Heartbeat timeout, seconds
    float hbPilotage = 0;           // Pilotage
    integer hbPilotageN = 0;        // Pilotage timeout counter

    //  Vehicle Auxiliary Messages
    integer LM_VX_INIT = 10;        // Initialise
    integer LM_VX_RESET = 11;       // Reset script
    integer LM_VX_STAT = 12;        // Print status
    integer LM_VX_PISTAT = 13;      // Print Pilotage status
    integer LM_VX_PIPANEL = 14;     // Display pilot's control panel
    integer LM_VX_HEARTBEAT = 15;   // Request heartbeat

    //  Pilotage messages
    integer LM_PI_STAT = 22;        // Print status

    //  Region Crossing messages
    integer LM_RX_STAT = 32;        // Print status

    //  Sounds Messages
    integer LM_SO_STAT = 42;        // Print status

    //  Script Processor messages
    integer LM_SP_STAT = 52;        // Print status

    //  Passengers messages
    integer LM_PA_STAT = 62;        // Print status

    //  Terrain Following messages
    integer LM_TF_STAT = 72;        // Print status

    //  SAM Sites messages
    integer LM_SA_STAT = 92;        // Print status

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
//llOwnerSay("ef (" + llGetSubString(s, o + 1, p) + ")  dig " + (string) digits + " dec " + (string) decimals);
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

    //  parcelFlags  --  Interpret llGetParcelFlags() bit values

    string parcelFlags(integer pflags) {
        string pft = "";
        if ((pflags & PARCEL_FLAG_ALLOW_FLY) == 0) {
            pft += " -FLY";
        }
        if ((pflags & PARCEL_FLAG_ALLOW_SCRIPTS) == 0) {
            pft += " -SCRIPTS";
        }
        if (pflags & PARCEL_FLAG_USE_ACCESS_GROUP) {
            pft += " +ACCGRP";
        }
        if (pflags & PARCEL_FLAG_USE_ACCESS_LIST) {
            pft += " +ACCLIST";
        }
        if (pflags & PARCEL_FLAG_USE_BAN_LIST) {
            pft += " +BAN";
        }
        if (pflags & PARCEL_FLAG_USE_LAND_PASS_LIST) {
            pft += " +PASS";
        }
        if (pflags & PARCEL_FLAG_ALLOW_ALL_OBJECT_ENTRY) {
            pft += " +ENTRYALL";
        }
        if (pflags & PARCEL_FLAG_ALLOW_GROUP_OBJECT_ENTRY) {
            pft += " +ENTRYGRP";
        }
        return pft;
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            hbPilotage = 0;                 // Reset heartbeat timers
            llSetTimerEvent(0.5);           // Start heartbeat timer
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//llOwnerSay("Vehicle auxiliary link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_VX_INIT (10): Initialise vehicle

            if (num == LM_VX_INIT) {

                //  Define vehicle properties

                llSetVehicleType(VEHICLE_TYPE_AIRPLANE);
                llSetVehicleVectorParam(VEHICLE_LINEAR_FRICTION_TIMESCALE,
                    <200, 20, 20>);

                //  Uniform angular friction

                llSetVehicleFloatParam(VEHICLE_ANGULAR_FRICTION_TIMESCALE, 2);

                //  Linear motor parameters (for front/back motion)

                llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION, <0, 0, 0>);
                llSetVehicleFloatParam(VEHICLE_LINEAR_MOTOR_TIMESCALE, 2);
                llSetVehicleFloatParam(VEHICLE_LINEAR_MOTOR_DECAY_TIMESCALE, 120);

                //  Angular motor parameters (for turning)

                llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION, <0, 0, 0>);
                llSetVehicleFloatParam(VEHICLE_ANGULAR_MOTOR_TIMESCALE, 0);
                llSetVehicleFloatParam(VEHICLE_ANGULAR_MOTOR_DECAY_TIMESCALE, 0.4);

                //  Hovering parameters

                llSetVehicleFloatParam(VEHICLE_HOVER_HEIGHT, 2);
                llSetVehicleFloatParam(VEHICLE_HOVER_EFFICIENCY, 0);
                llSetVehicleFloatParam(VEHICLE_HOVER_TIMESCALE, 10000);
                llSetVehicleFloatParam(VEHICLE_BUOYANCY, 1.0);              // Maintain existing altitude

                //  Disable linear deflection

                llSetVehicleFloatParam(VEHICLE_LINEAR_DEFLECTION_EFFICIENCY, 0);
                llSetVehicleFloatParam(VEHICLE_LINEAR_DEFLECTION_TIMESCALE, 5);

                //  Disable angular deflection

                llSetVehicleFloatParam(VEHICLE_ANGULAR_DEFLECTION_EFFICIENCY, 0);
                llSetVehicleFloatParam(VEHICLE_ANGULAR_DEFLECTION_TIMESCALE, 5);

                //  Disable vertical attractor
                llSetVehicleFloatParam(VEHICLE_VERTICAL_ATTRACTION_EFFICIENCY, 1);
                llSetVehicleFloatParam(VEHICLE_VERTICAL_ATTRACTION_TIMESCALE, 1);

                /*  We steer by banking, as on a motorcycle or in an
                    aircraft with co-ordinated turns.  The following
                    parameters specify how banking behaves, and can be
                    interpreted as how responsive the vehicle is to the
                    the left and right arrow keys whilst moving.  */

                llSetVehicleFloatParam(VEHICLE_BANKING_EFFICIENCY, 1);
                llSetVehicleFloatParam(VEHICLE_BANKING_MIX, 0.5);
                llSetVehicleFloatParam(VEHICLE_BANKING_TIMESCALE, 0.01);

                /*  We rotate our local frame with respect to the
                    global co-ordinate system as follows.  */

                llSetVehicleRotationParam(VEHICLE_REFERENCE_FRAME, llEuler2Rot(< 0, -(PI / 2), 0 >));

                //  Remove these flags
                llRemoveVehicleFlags(VEHICLE_FLAG_NO_DEFLECTION_UP |
                                     VEHICLE_FLAG_HOVER_WATER_ONLY |
                                     VEHICLE_FLAG_LIMIT_ROLL_ONLY |
                                     VEHICLE_FLAG_HOVER_TERRAIN_ONLY |
                                     VEHICLE_FLAG_HOVER_GLOBAL_HEIGHT |
                                     VEHICLE_FLAG_HOVER_UP_ONLY |
                                     VEHICLE_FLAG_LIMIT_MOTOR_UP);

            //  LM_VX_RESET (11): Reset script

            } else if (num == LM_VX_RESET) {
                llResetScript();

            //  LM_VX_STAT (12): Report Vehicle Management status

            } else if (num == LM_VX_STAT) {
                list arg = llJson2List(str);
                integer autoEngaged = llList2Integer(arg, 0);
                float autoRange = llList2Float(arg, 1);
                integer mFree = llList2Integer(arg, 2);
                integer mUsed = llList2Integer(arg, 3);
                float X_THRUST = llList2Float(arg, 4);
                float Z_THRUST = llList2Float(arg, 5);
                integer lSaddle = llList2Integer(arg, 6);

                integer pflags = llGetParcelFlags(llGetPos());
                string pft = parcelFlags(pflags);

                string stat = "Vehicle management status:\n" +
                    "Position: " + llGetRegionName() + " " + ef((string) llGetPos()) + "\n" +
                    "Rotation: " + ef((string) (llRot2Euler(llGetRot()) * RAD_TO_DEG)) + "\n" +
                    "Velocity: " + ef((string) llGetVel()) + " " +
                        ef((string) llVecMag(llGetVel())) + " m/s\n" +
                    "Parcel: " + llList2String(llGetParcelDetails(llGetPos(), [ PARCEL_DETAILS_NAME ]), 0) +
                        "  Flags " + (string) pflags + pft + "\n" +
                    "Physics: " + (string) llGetStatus(STATUS_PHYSICS) + "\n" +
                    "Thrust: Horiz " + ef((string) X_THRUST) + "  Vert " + ef((string) Z_THRUST) + "\n";
                stat += "Omega: " + ef(llList2CSV(llGetPrimitiveParams([ PRIM_OMEGA ]))) + "\n";
                if (autoEngaged) {
                    stat += "Autopilot engaged.  Range " + (string) ((integer) llRound(autoRange)) + " metres\n";
                }

                stat += "Vehicle Management script memory.  Free: " + (string) mFree +
                      "  Used: " + (string) mUsed + " (" +
                      (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)\n";


                mFree = llGetFreeMemory();
                mUsed = llGetUsedMemory();
                stat += "Vehicle auxiliary script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";

                llRegionSayTo(id, PUBLIC_CHANNEL, stat);        // Vehicle management
                llMessageLinked(LINK_THIS, LM_PI_STAT, "", id); // Pilotage
                llMessageLinked(LINK_THIS, LM_PA_STAT, "", id); // Passengers
                llMessageLinked(LINK_THIS, LM_RX_STAT, "", id); // Region crossing
                llMessageLinked(LINK_THIS, LM_SP_STAT, "", id); // Script processing
                llMessageLinked(LINK_THIS, LM_TF_STAT, "", id); // Terrain following
                llMessageLinked(LINK_THIS, LM_SA_STAT, "", id); // SAM sites
                llMessageLinked(lSaddle, LM_SO_STAT, "", id);   // Sounds

            //  LM_VX_STAT (13): Report Pilotage status

            } else if (num == LM_VX_PISTAT) {
                list arg = llJson2List(str);
                float statMETstart = llList2Float(arg, 0);
                float statMETlast = llList2Float(arg, 1);
                float statDistance = llList2Float(arg, 2);
                integer statRegionX = llList2Integer(arg, 3);
                integer statDests = llList2Integer(arg, 4);
                integer statLand = llList2Integer(arg, 5);
                integer statSAM = llList2Integer(arg, 6);
                integer statCorner = llList2Integer(arg, 7);
                integer statCollO = llList2Integer(arg, 8);
                integer statCollT = llList2Integer(arg, 9);
                integer statDrop = llList2Integer(arg, 10);
                integer T_nhits = llList2Integer(arg, 11);
                integer T_nscore = llList2Integer(arg, 12);
                vector fwd = (vector) llList2String(arg, 13);
                float edge0 = llList2Float(arg, 14);
                string edge1 = llList2String(arg, 15);
                string quad = llList2String(arg, 16);
                float cor = llList2Float(arg, 17);
                integer mFree = llList2Integer(arg, 18);
                integer mUsed = llList2Integer(arg, 19);
                key agent = llList2Key(arg, 20);
                integer perms = llList2Integer(arg, 21);
                key pfk = llList2Key(arg, 22);

                string stat = "Pilotage status:  \n";
                integer ftime = 0;
                if (agent != NULL_KEY) {
                    ftime = (integer) llRound(llGetTime() - statMETstart);
                    stat += "    Pilot: " +
                        (string) agent + " (" + llKey2Name(agent) + ")\n";
                } else {
                    if (statMETstart > 0) {
                        ftime = (integer) llRound(statMETlast - statMETstart);
                    }
                    stat += "    No pilot seated.\n";
                }
                string metstat = "";
                if (ftime > 0) {
                    metstat = "    Flight time: " + (string) ftime + " s  Mean speed: " +
                        ef((string) (statDistance / ftime)) + " m/s\n";
                }
                stat +=
                        "    Distance travelled: " + (string) ((integer) llRound(statDistance)) + " m\n" +
                        metstat +
                        "    Regions crossed: " + (string) statRegionX + "\n" +
                        "    Destinations: " + (string) statDests + "\n" +
                        "    Landings: " + (string) statLand + "\n" +
                        "    SAM diverts: " + (string) statSAM + "\n" +
                        "    Corner diverts: " + (string) statCorner + "\n" +
                        "    Collisions:  " + (string) statCollO + " obstacles, " +
                            (string) statCollT + " terrain" + "\n" +
                        "    Anvils dropped: " + (string) statDrop +
                            "  Hits: " + (string) T_nhits + "  Score: " + (string) T_nscore + "\n";
                        stat += "    Closest edge: " + edge1 + " " +
                            (string) ((integer) llRound(edge0)) + " m" +
                            "  Corner: " + (string) ((integer)
                            llRound((cor * RAD_TO_DEG))) + "°" +
                                "  Fwd: " + ef((string) fwd) +
                                "  Quad: " + quad + "\n";
                string pft = "";
                if (perms & PERMISSION_TAKE_CONTROLS) {
                    pft += " +CTL";
                }
                if (perms & PERMISSION_TRIGGER_ANIMATION) {
                    pft += " +ANIM";
                }
                if (perms & PERMISSION_CONTROL_CAMERA) {
                    pft += " +CAM";
                }
                stat += "    Permissions: " + (string) perms + pft + " granted by " +
                    (string) pfk + "\n";
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";
                llRegionSayTo(id, PUBLIC_CHANNEL, stat);

            //  LM_VX_PIPANEL (14): Update and display pilot's control panel

            } else if (num == LM_VX_PIPANEL) {
                list arg = llJson2List(str);

                vector fwd = (vector) llList2String(arg, 0);
                vector p = (vector) llList2String(arg, 1);
                float tfTerrain =  llList2Float(arg, 2);
                string destRegion = llList2String(arg, 3);
                float trueRange = llList2Float(arg, 4);
                float bear = llList2Float(arg, 5);
                float velDestSmooth = llList2Float(arg, 6);
                integer stalledWarn = llList2Integer(arg, 7);
                integer autoDivertActive = llList2Integer(arg, 8);
                integer autoEngaged = llList2Integer(arg, 9);
                string autoDivertSite = llList2String(arg, 10);
                float autoDivertRange = llList2Float(arg, 11);
                integer autoCornerDivert = llList2Integer(arg, 12);
                vector cornerDivertPos = (vector) llList2String(arg, 13);
                integer statDrop = llList2Integer(arg, 14);
                integer T_nhits = llList2Integer(arg, 15);
                integer T_nscore = llList2Integer(arg, 16);

                float abear = PI_BY_TWO - llAtan2(fwd.y, fwd.x);
                abear = abear * RAD_TO_DEG;
                if (abear < 0) {
                    abear = 360 + abear;
                }

                string legend =
                    "Bearing " + (string) (((integer) llRound(abear))) +  "°\n" +
                    "Alt " + (string) ((integer) llRound(p.z)) + " m  Terr " +
                    (string) ((integer) llRound(tfTerrain)) + " m";
                if (destRegion != "") {
                    legend += "\nRange " + (string) ((integer) llRound(trueRange)) + " m\n" +
                              "Azimuth: " + (string) llRound(bear * RAD_TO_DEG) + "°";
                }
                if (velDestSmooth != -9999) {
                    float vds2d = ((integer) llRound(velDestSmooth * 100)) / 100.0;
                    legend += "\nVelocity: " + ef((string) vds2d);
                    if (stalledWarn) {
                        legend += " (stalled)";
                    }
                }
                if (autoDivertActive) {
                    string dorw = "warning";
                    if (autoEngaged) {
                        dorw = "divert";
                    }
                    legend += "\nSAM " + dorw + ": " + autoDivertSite + " " +
                        (string) ((integer) llRound(autoDivertRange)) + " m";
                }
                if (autoCornerDivert) {
                    legend += "\nCorner divert to " + llGetRegionName() +
                        " " + ef((string) cornerDivertPos);
                }
                if (statDrop > 0) {
                    legend += "\nBombs " + (string) statDrop +
                              "  Hits " + (string) T_nhits +
                              "  Score " + (string) T_nscore;
                }
                llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_TEXT, legend, < 0, 1, 0 >, 1 ]);

            //  LM_VX_HEARTBEAT (15): Heartbeat received

            } else if (num == LM_VX_HEARTBEAT) {
                if (str == "PILOTAGE") {
                    hbPilotage = llGetTime();
                    if (hbPilotageN > 0) {
llOwnerSay("Pilotage script restored.");
                        hbPilotageN = 0;
                    }
                }
            }
        }

        //  timer()  --  Request heartbeat from other components

        timer() {
            llMessageLinked(LINK_THIS, LM_VX_HEARTBEAT, "REQ", NULL_KEY);
            
            //  Check for heartbeat failure from other scripts
            
            float t = llGetTime();
            
            if ((hbPilotage - t) > hbTimeout) {
if (hbPilotageN == 0) {
    llOwnerSay("Pilotage script timeout.");
}
                hbPilotageN++;
            }
        }
    }
