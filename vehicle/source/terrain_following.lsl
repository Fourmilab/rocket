   /*

               Fourmilab Terrain Following

                    by John Walker

    */

    //  Terrain following messages
    integer LM_TF_INIT = 70;        // Initialise
    integer LM_TF_RESET = 71;       // Reset script
    integer LM_TF_STAT = 72;        // Print status
    integer LM_TF_ACTIVATE = 73;    // Turn terrain following on or off
    integer LM_TF_TERRAIN = 74;     // Report terrain height to client

    //  Pilotage messages
    integer LM_PI_PILOT = 27;       // Pilot sit / unsit

    //  Trace messages
    integer LM_TR_SETTINGS = 120;       // Broadcast trace settings
    //  Trace module selectors
    integer LM_TR_S_TERR = 64;          // Terrain Following

    integer tfActive = FALSE;       // Is terrain following active ?
    float tfRate = 1;               // Poll rate in seconds
    float tfStart = 3.0;            // Terrain following minimum range (to avoid vehicle)
    float tfRange = 100;            // Terrain following maximum range
    integer REGION_SIZE = 256;      // Size of region in metres

    float terrain = 0;              // Most recent terrain probe

    key myself;                     // My own key

    key owner;                      // Owner of the vehicle
    key agent = NULL_KEY;           // Pilot, if any
    integer tfTrace;                // Generate trace output ?

    //  max  --  Maximum of two float arguments

    float max(float a, float b) {
        if (a > b) {
            return a;
        } else {
            return b;
        }
    }

    /*  tawk  --  Send a message to the interacting user in chat.
                  The recipient of the message is defined as
                  follows.  If an agent is on the pilot's seat,
                  that avatar receives the message.  Otherwise,
                  the message goes to the owner of the object.
                  In either case, if the message is being sent to
                  the owner, it is sent with llOwnerSay(), which isn't
                  subject to the region rate gag, rather than
                  llRegionSayTo().  */
/* IF TERRAIN_TRACE */
    tawk(string msg) {
        key whom = owner;
        if (agent != NULL_KEY) {
            whom = agent;
        }
        if (whom == owner) {
            llOwnerSay(msg);
        } else {
            llRegionSayTo(whom, PUBLIC_CHANNEL, msg);
        }
    }
/* END TERRAIN_TRACE */

    /*  ttawk  --  Send a message with tawk(), but only if tfTrace
                   is nonzero.  This should only be used for simple
                   messages generated infrequently.  For complex,
                   high-volume messages you should use:
                       if (tfTrace) { tawk(whatever); }
                   because that will not generate the message or call a
                   function when trace is not set.  */

/* IF TERRAIN_TRACE */
    ttawk(string msg) {
        if (tfTrace) {
            tawk(msg);
        }
    }
/* END TERRAIN_TRACE */

    /*  regionEdge  --  Distance to edge of region along
                        current trajectory.  */

    list regionEdge(vector pos, vector dir) {
        float EPSILON = 1e-5;

        dir.z = 0;                      // We're only interested in horizonal dist
        pos.z = 0;
        dir = llVecNorm(dir);           // Need to re-normalise in case .z changed

        float distEW = 1e30;            // Distance to East or West edge
        float distNS = 1e30;            // Distance to North or South edge
        string sideEW = "";
        string sideNS = "";

        //  Check Y axis edges

        if (dir.x < -EPSILON) {         // Does it intersect the west edge ?
            distEW = -pos.x / dir.x;    // Distance to west (X = 0) edge
            sideEW = "W";
        } else if (dir.x > EPSILON) {   // Does it intersect the east edge ?
            distEW = (-(pos.x - REGION_SIZE)) / dir.x; // Distance to east (X = REGION_SIZE) edge
            sideEW = "E";
        }

        //  Check X axis edges

        if (dir.y < -EPSILON) {         // Does it intersect the south edge ?
            distNS = -pos.y / dir.y;    // Distance to south (Y = 0) edge
            sideNS = "S";
        } else if (dir.y > EPSILON) {   // Does it intersect the north edge ?
            distNS = (-(pos.y - REGION_SIZE)) / dir.y; // Distance to north (X = REGION_SIZE) edge
            sideNS = "N";
        }

        //  Return the smaller of the two edge intersection distances

        if (distEW < distNS) {
            return [ distEW, sideEW ];
        }
        return [ distNS, sideNS ];
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            owner = llGetOwner();
            myself = llGetKey();       // My own UUID
            tfActive = FALSE;
            llSetTimerEvent(0);
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//ttawk("Terrain following link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_TF_INIT (70): Initialise terrain following

            if (num == LM_TF_INIT) {

            //  LM_TF_RESET (71): Reset script

            } else if (num == LM_TF_RESET) {
                llResetScript();

            //  LM_TF_STAT (72): Report status

            } else if (num == LM_TF_STAT) {
                string stat = "Terrain following:  Active: " + (string) tfActive + "\n";
                if (tfActive) {
                    stat += "Terrain height: " + (string) ((integer) llRound(terrain)) + " m\n";
                }
                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";

                llRegionSayTo(id, PUBLIC_CHANNEL, stat);

            //  LM_TF_ACTIVATE (73): Activate/deactivate terrain following

            } else if (num == LM_TF_ACTIVATE) {
                list args = llJson2List(str);
                tfActive = llList2Integer(args, 0);         // Active / Inactive
                tfRate = llList2Float(args, 1);             // Poll rate

                if (tfActive) {
                    llSetTimerEvent(tfRate);
                } else {
                    llSetTimerEvent(0);
                }

            //  LM_PI_PILOT (27): Set pilot agent key

            } else if (num == LM_PI_PILOT) {
                agent = id;

            //  LM_TR_SETTINGS (120): Set trace modes

            } else if (num == LM_TR_SETTINGS) {
                tfTrace = (llList2Integer(llJson2List(str), 0) & LM_TR_S_TERR) != 0;

            }
        }

        //  The timer triggers polls and reports to the client

        timer() {
            if (tfActive) {

                /*  Terrain following: probe terrain below and before us and
                    compute the highest point.

                    Well, yes...and here we go again.  The Second Life LSL wiki
                    for llGround and llWater:
                        http://wiki.secondlife.com/wiki/LlGround
                        http://wiki.secondlife.com/wiki/LlWater
                    both unambiguously state, regarding the the offset
                    argument:
                        vector offset -- offset relative to the prim's position and
                                         expressed in local coordinates
                        Only the x and y coordinates in offset are important, the
                            z component is ignored.
                    This is complete bollocks.  In fact, the offset argument is in
                    *global* (region) co-ordinates, and it is up to the caller to
                    transform local co-ordinates of the prim in which the script
                    resides into region co-ordinates.  This bug has been known
                    since at least 2007-09-03:
                        http://forums-archive.secondlife.com/54/99/208350/1.html
                    *more than twelve years ago* at this writing, and nothing
                    has been done to make the documentation conform to the
                    operation of the function or vice versa.  At this late date,
                    the only option would be to correct the documentation, since
                    fixing the function to behave as documented would doubtless
                    break innumerable scripts.

                    Here, since we're in a root prim which is a cylinder (the
                    rocket body) which is rotated to align its local +Z axis with
                    the +X axis of the vehicle's motion, if we wish to look at
                    terrain in our direction of motion, we must transform a
                    vector with a distance in our local Z axis by our current
                    global rotation, for example to peek 10 metres ahead at the
                    ground level:
                        llGround(<0, 0, 10> * llGetRot())

                    Think about this: everybody who has written code what uses
                    llGround() or llWater() based upon the description in the wiki
                    has had to discover this for themselves for more than twelve
                    years.
                */

                rotation r = llGetRot();
                //  We can't look beyond the region, so restrict if close to edge
                tfRange = llList2Float(regionEdge(llGetPos(), llRot2Up(llGetLocalRot())), 0);
//llOwnerSay("tfRange to edge " + (string) tfRange);
                terrain = max(llGround(ZERO_VECTOR), llWater(ZERO_VECTOR));
                 if (tfRange > 10) {
                    float terrain10 = max(llGround(<0, 0, 10> * r), llWater(<0, 0, 10> * r));
                    terrain = max(terrain, terrain10);
                    if (tfRange > 25) {
                        float terrain25 = max(llGround(<0, 0, 25> * r), llWater(<0, 0, 25> * r));
                        terrain = max(terrain, terrain25);
                        if (tfRange > 50) {
                            float terrain50 = max(llGround(<0, 0, 50> * r), llWater(<0, 0, 50> * r));
                            terrain = max(terrain, terrain50);
                        }
                    }

                    /*  Now refine our estimate by casting a ray in the direction
                        we're flying and seeing if it hits anything.  */

                    vector p = llGetPos();
                    list rcr = llCastRay(p + <0, 0, tfStart> * r, p + (< 0, 0, tfRange > * r),
                        [ RC_REJECT_TYPES, RC_REJECT_AGENTS, RC_MAX_HITS, 5 ]);
                    integer rcstat = llList2Integer(rcr, -1);
                    float conflictAlt = 0;
                    integer nhits = 0;
                    if (rcstat > 0) {
                        integer i;
                        for (i = 0; i < rcstat; i++) {
                            key what = llList2Key(rcr, i * 2);
                            vector where = llList2Vector(rcr, (i * 2) + 1);
                            string which = "Ground";
                            if (what != NULL_KEY) {
                                which = llKey2Name(what);
                            }
/* IF TERRAIN_TRACE */
                            ttawk("Detected " + which + " at " + (string) where +
                                  ", range " + (string) llVecDist(p, where));
/* END TERRAIN_TRACE */
                            /*  During the screwball perturbations after a turbulent
                                region crossing, it is possible for our ray casting
                                to detect parts of the vehicle itself, presumably
                                because the vehicle's co-ordinates haven't settled
                                after arriving in the receiving region.  We test
                                for these self-detections and ignore them.  */
                            if ( llList2Key(llGetObjectDetails(what,
                                [ OBJECT_ROOT ]), 0) == myself) {
/* IF TERRAIN_TRACE */
                                ttawk("Detected myself: " + which + " at " + (string) where +
                                      ", range " + (string) llVecDist(p, where));
/* END TERRAIN_TRACE */
                            } else {
                                conflictAlt = max(conflictAlt, where.z);
                                nhits++;
                            }
                        }

                        if (nhits > 0) {
                            /*  Now probe with rays at successively higher elevations
                                at the end until we find one which doesn't hit.  */
                            float probeElev = 10;
                            integer e;
                            integer nhitsE;
                            for (e = 0; e < 20; e++) {
                                rcr = llCastRay(p + <0, 0, tfStart> * r,
                                                p + (< 0, 0, tfRange > * r) + <0, 0, probeElev>,
                                    [ RC_REJECT_TYPES, RC_REJECT_AGENTS, RC_MAX_HITS, 5 ]);
                                rcstat = llList2Integer(rcr, -1);
/* IF TERRAIN_TRACE */
                                ttawk("Elevation " + (string) probeElev + "  rcstat " + (string) rcstat);
/* END TERRAIN_TRACE */
                                float conflictAltE = 0;
                                nhitsE = 0;
                                if (rcstat >= 0) {
                                    integer j;
                                    for (j = 0; j < rcstat; j++) {
                                        key what = llList2Key(rcr, j * 2);
                                        vector where = llList2Vector(rcr, (j * 2) + 1);
                                        string which = "Ground";
                                        if (what != NULL_KEY) {
                                            which = llKey2Name(what);
                                        }
/* IF TERRAIN_TRACE */
                                        ttawk("Detected " + which + " at " + (string) where +
                                              ", range " + (string) llVecDist(p, where) +
                                              " at elevation " + (string) probeElev);
/* END TERRAIN_TRACE */
                                        conflictAltE = max(conflictAltE, where.z);
                                        nhitsE++;
                                    }
                                    if (nhitsE > 0) {
/* IF TERRAIN_TRACE */
                                        ttawk("Elevation " + (string) probeElev + "  Hits " +
                                              (string) nhitsE + " at " + (string) conflictAltE);
/* END TERRAIN_TRACE */
                                        conflictAlt = max(conflictAlt, conflictAltE);
                                        probeElev += 10;
                                    } else {
/* IF TERRAIN_TRACE */
                                        ttawk("Elevation " + (string) probeElev +
                                              " no hits.  Clear of conflict at " +
                                              (string) conflictAlt + " m");
/* END TERRAIN_TRACE */
                                        jump clear;
                                    }
                                }
/* IF TERRAIN_TRACE */
                                  else if (rcstat < 0) {
                                    //  This usually reports status -2, which means the region is too busy
                                    ttawk("Ray cast failed, status " + (string) rcstat +
                                          " at elevation " + (string) probeElev);
                                }
/* END TERRAIN_TRACE */
                            }
                            @clear;
/* IF TERRAIN_TRACE */
                            ttawk("Ray casting terrain estimation " + (string) conflictAlt);
/* END TERRAIN_TRACE */
                        }
/* IF TERRAIN_TRACE */
                          else {
                            ttawk("No hits.");
                        }
/* END TERRAIN_TRACE */
                    }
/* IF TERRAIN_TRACE */
                      else if (rcstat < 0) {
                        ttawk("Ray cast failed, status " + (string) rcstat);
                    }
/* END TERRAIN_TRACE */

                    //  Incorporate ray casting estimate into terrain
                    llMessageLinked(LINK_THIS, LM_TF_TERRAIN,
                        llList2Json(JSON_ARRAY, [ terrain, conflictAlt ]), NULL_KEY);

                }
            }
        }
    }
