     /*

               Fourmilab SAM Sites Module

                    by John Walker

    */

    key whoDat = NULL_KEY;          // Avatar who sent command
    key owner;                      // UUID of owner
    key agent = NULL_KEY;           // Pilot, if any

    integer saTrace = FALSE;        // Trace operation ?
    float samRange = 1024;          // Range in which we scan, metres
    float samMargin = 2;            // Vehicle clearance margin, metres
    integer scriptActive;           // Did Set SAM command come from script ?

    integer siteChannel = -982449720;   // Channel for communicating with sites
    integer impactH = 0;            // Handle for impact listener
    string impactAction = "ig";     // Action for SAM impacts

    //  Link indices within the object

    integer lSounds;                // Link containing sound and light

    list lastScan = [ ];            // Last threat scan arguments

    /*  The samSites table is a list consisting of items
        as follows:
            0   string region_name
            1   vector region_grid_coordinates
            2   vector site_coordinates_in_region
            3   float threat_radius
            4   float threat_altitude
            5   string label
    */
    list samSites = [ ];
    integer samSitesN = 6;      // List items per site entry

    //  Region queries

    integer REGION_SIZE = 256;  // Size of region in metres
    string rnameQ;              // Region name being queried
    key regionQ = NULL_KEY;     // Query region handle
    integer stateQ = 0;         /* Query state:
                                        0   Idle
                                        1   Requesting status
                                        2   Requesting grid position */

    string destRegion = "";     // Region name of destination
    vector destGrid;            // Grid co-ordinates of destination
    vector destRegc;            // Destination co-ordinates within region
    string samLabel;            // Label for pending query
    float samRad;               // Threat radius of pending query
    float samAlt;               // Threat altitude of pending query


    //  SAM Sites messages
    integer LM_SA_INIT = 90;        // Initialise
    integer LM_SA_RESET = 91;       // Reset script
    integer LM_SA_STAT = 92;        // Print status
    integer LM_SA_COMMAND = 94;     // Process command from chat or script
    integer LM_SA_COMPLETE = 95;    // Chat command processing complete
    integer LM_SA_PROBE = 96;       // Probe for threats
    integer LM_SA_DIVERT = 97;      // Diversion temporary waypoint advisory

    integer DEFER = 2;              // Status indicating deferred reply from LM_SA_COMMAND

    //  Pilotage messages
    integer LM_PI_FIRE = 26;        // Fire weapon / handle impact
    integer LM_PI_PILOT = 27;       // Pilot sit / unsit

    //  Sounds messages
    integer LM_SO_FLASH = 45;       // Explosion particle effect

    //  Trace messages
    integer LM_TR_SETTINGS = 120;       // Broadcast trace settings
    //  Trace module selectors
    integer LM_TR_S_SAM = 8;            // SAM Sites

    /*  Find a linked prim from its name.  Avoids having to slavishly
        link prims in order in complex builds to reference them later
        by link number.  You should only call this once, in state_entry(),
        and then save the link numbers in global variables.  Returns the
        prim number or -1 if no such prim was found.  Caution: if there
        are more than one prim with the given name, the first will be
        returned without warning of the duplication.  */

    integer findLinkNumber(string pname) {
        integer i = llGetLinkNumber() != 0;
        integer n = llGetNumberOfPrims() + i;

        for (; i < n; i++) {
            if (llGetLinkName(i) == pname) {
                return i;
            }
        }
        return -1;
    }

    /*  tawk  --  Send a message to the interacting user in chat.
                  The recipient of the message is defined as
                  follows.  If the command is from a Set SAM
                  command, reply to whoever submitted the command.
                  If an agent is on the pilot's seat,
                  that avatar receives the message.  Otherwise,
                  the message goes to the owner of the object.
                  In either case, if the message is being sent to
                  the owner, it is sent with llOwnerSay(), which isn't
                  subject to the region rate gag, rather than
                  llRegionSayTo().  */

    tawk(string msg) {
        key whom = owner;
        if (agent != NULL_KEY) {
            whom = agent;
        }
        if (whoDat != NULL_KEY) {
            whom = whoDat;
        }
        if (whom == owner) {
            llOwnerSay(msg);
        } else {
            llRegionSayTo(whom, PUBLIC_CHANNEL, msg);
        }
    }

/*
    //  ttawk  --  Send a message if trace mode is on

    ttawk(string msg) {
        if (saTrace) {
            tawk(msg);
        }
    }
*/

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
//tawk("ef (" + llGetSubString(s, o + 1, p) + ")  dig " + (string) digits + " dec " + (string) decimals);
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

    /*  parseDestination  --  Parse destination from location or SLUrl.
                              Returns a list containing the region name
                              and co-ordinates within the region.  The
                              format for destinations are as follows:

                    "Fourmilab Island, Fourmilab (120, 122, 27) - Moderate"
                    "http://maps.secondlife.com/secondlife/Fourmilab/120/122/28"
                    "secondlife://Fourmilab/128/128/50"
    */

    list parseDestination(string dest) {
        if (llSubStringIndex(dest, "http://") >= 0) {
            /*  SLUrl like:
                "http://maps.secondlife.com/secondlife/Fourmilab/120/122/28" */
            list url = llParseString2List(dest, [ "/" ], []);
            return [ llUnescapeURL(llList2String(url, 3)),
                     < llList2Float(url, 4), llList2Float(url, 5), llList2Float(url, 6) > ];
        } else if (llSubStringIndex(dest, "secondlife://") >= 0) {
            /*  SLUrl like:
                "http://maps.secondlife.com/secondlife/Fourmilab/120/122/28" */
            list url = llParseString2List(dest, [ "/" ], []);
            return [ llUnescapeURL(llList2String(url, 1)),
                     < llList2Float(url, 2), llList2Float(url, 3), llList2Float(url, 4) > ];
        } else {
            /*  Primate-readable destination like:
                "Fourmilab Island, Fourmilab (120, 122, 27) - Moderate" */
            list result = [ ];
            integer regstart = llSubStringIndex(dest, ", ");
            if (regstart >= 0) {
                list comps = llParseString2List(llGetSubString(dest, regstart + 2, -1), [ " " ], []);
                result = [ llList2String(comps, 0),
                           < (float) llGetSubString(llList2String(comps, 1), 1, -2),
                             (float) llGetSubString(llList2String(comps, 2), 0, -2),
                             (float) llGetSubString(llList2String(comps, 3), 0, -2) > ];
            }
            return result;
        }
    }

    //  abbrP  --  Test if string matches abbreviation

    integer abbrP(string str, string abbr) {
        return abbr == llGetSubString(str, 0, llStringLength(abbr) - 1);
    }

    //  eOn  --  Edit a Boolean value to "on" or "off"

    string eOn(integer b) {
        if (b) {
            return "on";
        }
        return "off";
    }

    //  eSite  --  Edit a SAM site (samSites list index) to string

    string eSite(integer n) {
        integer x = n * samSitesN;
        return (string) (n + 1) + " [" + llList2String(samSites, x + 5) + "]";
    }

    //  listSites  --  List SAM sites

    listSites(string pfx) {
        integer n = llGetListLength(samSites) / samSitesN;

        if (n == 0) {
            tawk(pfx + "No SAM sites.");
        } else {
            integer i;

            tawk(pfx + (string) n + " SAM sites:  Num  Region  Grid  Local  Radius  Altitude  Label");
            for (i = 0; i < n; i++) {
                integer x = i * samSitesN;
                tawk(pfx +
                     "  " + (string) (i + 1) + ".  " + llList2String(samSites, x) +
                     "  " + ef((string) llList2Vector(samSites, x + 1)) +
                     "  " + ef((string) llList2Vector(samSites, x + 2)) +
                     "  " + ef((string) llList2Float(samSites, x + 3)) +
                     "  " + ef((string) llList2Float(samSites, x + 4)) +
                     "  " + llList2String(samSites, x + 5));
            }
        }
    }

    //  processCommand  --  Process a command

    integer processCommand(key id, string message) {

        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments
        integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command
//tawk("SAM command: " + llList2CSV(args));

        whoDat = id;            // Direct chat output to sender of command

        if (abbrP(command, "se") && abbrP(llList2String(args, 1), "sa")) {
            string param = llList2String(args, 2);
            //  Number of sites for convenience in commands below
            integer n = llGetListLength(samSites) / samSitesN;

            //  Set SAM delete all/n

            if (abbrP(param, "de")) {
                if (argn < 4) {
                    tawk("No SAM site number/all specified.");
                    return FALSE;
                } else {
                    if (abbrP(llList2String(args, 3), "al")) {  // all
                        samSites = [ ];
                    } else {
                        integer d = llList2Integer(args, 3);
                        if ((d < 1) || (d > n)) {
                            tawk("Invalid SAM site number.");
                            return FALSE;
                        } else {
                            integer x = (d - 1) * samSitesN;
                            samSites = llDeleteSubList(samSites, x, x + (samSitesN - 1));
                        }
                    }
                }

            //  Set SAM impact ignore/disable/eject/explode/warn

            } else if (abbrP(param, "im")) {
                string action = llList2String(args, 3);

                if (abbrP(action, "ig")) {
                    if (impactH != 0) {
                        llListenRemove(impactH);
                        impactH = 0;
                    }
                } else if (abbrP(action, "di") || abbrP(action, "ej") ||
                           abbrP(action, "ex") || abbrP(action, "wa")) {
                    impactAction = llGetSubString(action, 0, 1);
                    if (impactH == 0) {
                        impactH = llListen(siteChannel, "", "", "");
                    }
                } else {
                    tawk("Invalid SAM impact action: ignore/disable/eject/explode/warn");
                }

            //  Set SAM list

            } else if (abbrP(param, "li")) {
                listSites("");

            //  Set SAM margin n

            } else if (abbrP(param, "ma")) {
                samMargin = llList2Float(args, 3);                  // Vehicle clearance margin

            //  Set SAM range n

            } else if (abbrP(param, "ra")) {
                samRange = llList2Float(args, 3);                   // Scanning range

            //  Set SAM scan

            } else if (abbrP(param, "sc")) {
                llSensor("SAM site", NULL_KEY, PASSIVE | SCRIPTED, 96, PI);

            //  Set SAM site ["label"] radius altitude location/SLUrl

            } else if (abbrP(param, "si")) {
                string l = llList2String(args, 3);
                samLabel = "";
                //  If the first argument begins with a quote, parse and remove label
                if (llGetSubString(l, 0, 0) == "\"") {
                    list ulargs = llParseString2List(message, [" "], []);
                    l = llList2String(ulargs, 3);
                    samLabel = llGetSubString(l, 1, -1);
                    ulargs = llDeleteSubList(ulargs, 3, 3);
                    args = llDeleteSubList(args, 3, 3);
                    while (llGetSubString(samLabel, -1, -1) != "\"") {
                        samLabel += " " + llList2String(ulargs, 3);
                        ulargs = llDeleteSubList(ulargs, 3, 3);
                        args = llDeleteSubList(args, 3, 3);
                    }
                    samLabel = llGetSubString(samLabel, 0, -2);
                }
                samRad = (float) llList2String(args, 3);            // Threat radius
                samAlt = (float) llList2String(args, 4);            // Threat altitude
                string loc = llList2String(args, 5);                // Start of location string
//tawk("rad " + (string) samRad + "  alt " + (string) samAlt + "  loc " + loc);
                integer dindex = llSubStringIndex(lmessage, " " + loc);
                list dl = [ ];
                if (dindex > 0) {
                    dl = parseDestination(llGetSubString(message, dindex + 1, -1));
                }
                if (dl == []) {
                    tawk("Invalid SAM site location " + llGetSubString(message, dindex + 1, -1));
                    return FALSE;
                } else {
                    rnameQ = llList2String(dl, 0);      // Destination region name
                    destRegion = "";                    // Mark destination unknown
                    destRegc = llList2Vector(dl, 1);    // Save location within region
                    stateQ = 1;
                    regionQ = llRequestSimulatorData(rnameQ, DATA_SIM_STATUS);
                    return DEFER;
                }

                //  Set SAM threats                 Display current threats

                } else if (abbrP(param, "th")) {
                    if (llGetListLength(lastScan) > 0) {
                        integer currTrace = saTrace;
                        saTrace = TRUE;
                        list t = threatScan(llList2Vector(lastScan, 0),
                                            llList2Vector(lastScan, 1),
                                            llList2Vector(lastScan, 2),
                                            llList2Vector(lastScan, 3));
                        saTrace = currTrace;
                        if (llGetListLength(t) > 0) {
                            tawk(ef("Closest threat: " + llList2String(t, 4) + " Range: " +
                                    (string) llList2Float(t, 1) + "  Waypoint: " +
                                    llList2String(samSites, (llList2Integer(t, 0) - 1) * samSitesN) +
                                     " " + (string) llList2Vector(t, 3)));
                        } else {
                            tawk("No threats.");
                        }
                } else {
                    tawk("No recent threat scan.");
                }

            } else {
                tawk("Invalid Set SAM command.");
                return FALSE;
            }
        } else {
            tawk("Huh?  SAM \"" + message + "\" undefined.");
            return FALSE;
        }
        return TRUE;
    }

    //  trMsg  --  Generate header for trace message

    string trMsg(integer idx, string stat) {
        return (string) (idx + 1) + stat + " " +
            llList2String(samSites, (idx * samSitesN) + 5) + "  ";

    }

    //  threatScan  --  Scan for threats along a current path

    list threatScan(
                      vector posG, vector posR,     // Current position in Grid, Region
                      vector destG, vector destR    // Destination in Grid, Region
                   ) {
//tawk(ef("threatScan pos " + (string) posG + " " + (string) posR + "  dest " + (string) destG + " " + (string) destR));
        lastScan = [ posG, posR, destG, destR ];    // Save last scan for threat display
        integer sites = llGetListLength(samSites) / samSitesN;
        list divert = [ ];
        float closestThreat = 1e30;                 // Distance to closest threat seen so far
        integer closestSite = -1;                   // Threat index of closest threat site
        vector divertVec;                           // Vector to divert past that threat
        string tr;

        if (saTrace) {
            tr = "SAM threat scan:";
        }

        if (sites > 0) {
            integer i;

            vector aposi = posG + <posR.x, posR.y, 0>;      // Absolute current position on ground
            vector adesti = destG + <destR.x, destR.y, 0>;  // Absolute destination on ground
            vector tbear = adesti - aposi;          // Current bearing
            vector tbearn = llVecNorm(tbear);       // Bearing normalised

            //  Walk through the SAM sites, evaluating threats

            list threats = [ ];
            integer threatn = 0;

            for (i = 0; i < sites; i++) {
                integer x = i * samSitesN;

                /*  The first thing we need to establish is the bearing
                    of the site with respect to the vector from our
                    current position to the destination.  If the site
                    is behind us, it's obviously no threat.  */

                //  Absolute site position
                vector sposa = (llList2Vector(samSites, x + 1) * REGION_SIZE) +
                               llList2Vector(samSites, x + 2);
                vector sposi = sposa;
                sposi.z = 0;
                vector sbear = sposi - aposi;       // Vector from our position to site
                vector sbearn = llVecNorm(sbear);   // The same, normalised
                float rbear = llAcos(sbearn * tbearn);  // Bearing of site to travel vector
                vector bdir = sbearn % tbearn;
                float bear = rbear;
                if (bdir.z < 0) {
                    bear = TWO_PI - bear;
                }
                float srange = llVecMag(sbear);

                /*  If the site is within our scanning range, proceed
                    with more detailed (and expensive) tests.  */

                if (srange <= samRange) {

                    /*  Now we're ready to test if the site is ahead or behind us.
                        Note that we could make this test later using the more
                        general test of whether the course intersects the
                        threat radius, but this serves as a quick reject that
                        saves us from doing a lot of calculation for, on average,
                        half the threats on the map.  */

                    if ((bear < PI_BY_TWO) || (bear > (3 * PI_BY_TWO))) {

                        /*  The site is ahead of us.  Now we must assess whether
                            it poses a risk based upon our current trajectory.
                            First of all, if we're flying at an altitude greater
                            than the site's range, we're OK and don't need to
                            worry about it.  */

                        float alt = posG.z + posR.z;    // Yes, posG.z is always zero, but who knows ?
                        float saltr = sposa.z + llList2Float(samSites, x + 4);
                        if (alt > saltr) {
                            if (saTrace) {
                                tr += "\n" + ef(trMsg(i, "-") + "Safe: our altitude " +
                                    (string) alt + " threat limit " + (string) saltr);
                            }
                        } else {

                            /*  We are at an altitude at which the site is a
                                threat.  Now we determine two vectors from our
                                position to either side of the threat radius
                                centred on the site and determine whether our
                                course vector lies between them.  If so, this
                                site is a candidate threat.  If it's closer
                                than any threat we've seen so far, it becomes
                                the prime threat.  */

                            float thrad = llList2Float(samSites, x + 3);
                            thrad += samMargin;         // Add vehicle clearance margin
                            float thrang = llAtan2(thrad, srange);
                            string tprobe;
                            if (saTrace) {
                                tprobe = "  Range " + (string) srange +
                                         "  Bearing " + (string) (bear * RAD_TO_DEG) +
                                         "  Threat rad " + (string) thrad +
                                         "  ang " + (string) (thrang * RAD_TO_DEG);
                            }
                            vector throff = (sbearn % <0, 0, 1>) * thrad;
                            vector threat1 = sbear + throff;
                            vector threat2 = sbear - throff;
                            threats += [ i, threat1, threat2 ];     // Save this threat
                            threatn++;
                            /*  The course vector (tbearn) lies between the two
                                vectors from our position to the edges of the
                                threat circle if the signs of the Z component of
                                the cross products of each edge vector and the
                                course vector and the other edge vector are the
                                sane.  */
                            vector v1xb = threat1 % tbearn;
                            vector v1x2 = threat1 % threat2;
                            vector v2xb = threat2 % tbearn;
                            vector v2x1 = threat2 % threat1;
                            integer inside = ((v1xb.z * v1x2.z) >= 0) &&
                                             ((v2xb.z * v2x1.z) >= 0);
                            if (inside) {
                                if (srange < closestThreat) {
                                    closestThreat = srange;
                                    closestSite = i;            // Index of closest threat

                                    /*  This is the closest threat we've seen so far.
                                        The vectors threat1 and threat2 represent the
                                        two edges of the threat's circle of danger.
                                        Select the one which makes the smallest
                                        angle (determined by the magnitude of the
                                        cross product of it with out course vector)
                                        as the waypoint to evade the threat, as it
                                        represents the smallest diversion from the
                                        direct course to the destination.  */

                                    divertVec = threat1;
                                    if (llVecMag(v2xb) < llVecMag(v1xb)) {
                                        divertVec = threat2;
                                    }
                                    if (saTrace) {
                                        tr += "\n" + ef(trMsg(i, "*") + "Closest threat at range " +
                                            (string) srange + ", divert to " +
                                            (string) divertVec + tprobe);
                                    }
                                } else {
                                    if (saTrace) {
                                        tr += "\n" + ef(trMsg(i, "-") + "Range of " + (string) srange +
                                            " greater than closest threat at " +
                                            (string) closestThreat) + tprobe;
                                    }
                                }
                            } else {
                                if (saTrace) {
                                    tr += "\n" + ef(trMsg(i, "-") + "Course does not intersect threat radius." +
                                        tprobe);
                                }
                            }
                        }
                    } else {
                        if (saTrace) {
                            tr += "\n" + trMsg(i, "-") + "Behind us.  Bearing " +
                                ef((string) (bear * RAD_TO_DEG));
                        }
                    }
                } else {
                    if (saTrace) {
                        tr += "\n" + trMsg(i, "-") + "Out of range: " +
                            ef((string) srange) + " metres";
                    }
                }
            }

            /*  Check whether the proposed diversion brings us into conflict
                with another of the threats.  If so, enter stage 2 conflict
                resolution.  */

            if ((threatn > 0) && (closestSite >= 0)) {
                integer j;
                integer k;
                integer stage2 = FALSE;

                for (j = k = 0; j < threatn; j++, k += 3) {
                    integer s = llList2Integer(threats, k);
                    vector dvn = llVecNorm(divertVec);
                    if (s != closestSite) {
                        vector th1 = llList2Vector(threats, k + 1);
                        vector th2 = llList2Vector(threats, k + 2);
                        vector v1xb = th1 % dvn;
                        vector v1x2 = th1 % th2;
                        vector v2xb = th2 % dvn;
                        vector v2x1 = th2 % th1;
                        integer inside = ((v1xb.z * v1x2.z) >= 0) &&
                                         ((v2xb.z * v2x1.z) >= 0);
                        if (inside) {
                            if (saTrace) {
                                llOwnerSay("Divert from site " + eSite(closestSite) +
                                           " conflicts with site " + eSite(s));
                            }
                            j = threatn;        // Escape from loop
                            stage2 = TRUE;      // Stage 2 resolution required
                        }
                    }
                }

                /*  Simple diversion around the closest threat brings us
                    into the threat sector of another within-range threat.
                    We now go off to consult with Mentor of Arisia for
                    Second Stage threat resolution.  Here's how it works.
                    For each threat within range, we generate diverts to
                    either side of its threat radius.  We then test each of
                    these diverts to see if it intersects the threat sector
                    of all other in-range threats.  If it does, it is
                    immediately eliminated as a candidate.  Diverts which
                    survive this test against all other threats are added
                    to a list of candidates.

                    After scanning all possible diverts, if one or more
                    candidates were found, we choose the one which has the
                    smallest angle with respect to a direct vector to the
                    destination.  If no candidate was found, this problem
                    is one we can't solve automatically, and we punt to the
                    pilot to get out of the mess.

                    Note that while Second Stage resolution works for many
                    common cases (in particular, the frequently encountered
                    situation of adjacent threats forming a barrier across
                    the desired path), there are situations which it cannot
                    evade which can nonetheless be avoided manually.  In
                    particular, it does not account for the distance to the
                    individual threats.  One can often get around a tight
                    situation by first evading nearby threats and then, when
                    they're behind us, dealing with those still ahead.  This
                    is, at the moment, left as an exercise for the reader.  */

                if (stage2) {
                    list divCand = [ ];         // Divert candidates
                    list divCandSite = [ ];     // Divert candidate sites

                    //  Iterate over threats
                    for (j = k = 0; j < threatn; j++, k += 3) {
                        //  Extract threat edges (candidate diverts) for this threat
                        vector div1 = llList2Vector(threats, k + 1);
                        vector div2 = llList2Vector(threats, k + 2);
                        integer divRemain = 2;          // Viable diverts remaining
/* IF SAM_TRACE */
                        if (saTrace) {
                            tawk("S2 Threat " + eSite(j) + " diverts " + (string) div1 + " " + (string) div2);
                        }
/* END SAM_TRACE */

                        //  Check each possible divert against other threats

                        integer l;
                        integer m;
                        for (l = m = 0; (divRemain > 0) && (l < threatn); l++, m += 3) {
                            if (l != j) {       // Don't check site against itself !
/* IF SAM_TRACE */
                                if (saTrace) {
                                    tawk("S2     Checking " + eSite(l));
                                }
/* END SAM_TRACE */
                                //  Extract threat edges for this site
                                vector th1 = llList2Vector(threats, m + 1);
                                vector th2 = llList2Vector(threats, m + 2);
                                vector v1x2 = th1 % th2;
                                vector v2x1 = th2 % th1;

                                //  Test if divert vectors within threat edges
                                if (div1 != ZERO_VECTOR) {
                                    vector v1xb = th1 % div1;
                                    vector v2xb = th2 % div1;
                                    integer inside = ((v1xb.z * v1x2.z) >= 0) &&
                                                     ((v2xb.z * v2x1.z) >= 0);
                                    if (inside) {
                                        /*  Divert 1 conflicts with this threat:
                                            eliminate as candidate.  */
                                        div1 = ZERO_VECTOR;
                                        divRemain--;
/* IF SAM_TRACE */
                                        if (saTrace) {
                                            tawk("S2         Threat " + eSite(j) + " divert 1 conflicts with site " + eSite(l));
                                        }
/* END SAM_TRACE */
                                    }
/* IF SAM_TRACE */
                                    else {
                                        if (saTrace) {
                                            tawk("S2         Threat " + eSite(j) + " divert 1 OK with site " + eSite(l));
                                        }
                                    }
/* END SAM_TRACE */
                                }
                                if (div2 != ZERO_VECTOR) {
                                    vector v1xb = th1 % div2;
                                    vector v2xb = th2 % div2;
                                    integer inside = ((v1xb.z * v1x2.z) >= 0) &&
                                                     ((v2xb.z * v2x1.z) >= 0);
                                    if (inside) {
                                        /*  Divert 2 conflicts with this threat:
                                            eliminate as candidate.  */
                                        div2 = ZERO_VECTOR;
                                        divRemain--;
/* IF SAM_TRACE */
                                        if (saTrace) {
                                            tawk("S2         Threat " + eSite(j) + " divert 2 conflicts with site " + eSite(l));
                                        }
/* END SAM_TRACE */
                                    }
/* IF SAM_TRACE */
                                    else {
                                        if (saTrace) {
                                            tawk("S2         Threat " + eSite(j) + " divert 2 OK with site " + eSite(l));
                                        }
                                    }
/* END SAM_TRACE */
                                }
                            }
                        }

                        /*  If either or both divert(s) around this threat
                            does not conflict with any other threat, add
                            to the list of candidate diverts.  */
                        if (div1 != ZERO_VECTOR) {
                            divCand += div1;
                            divCandSite += j;
/* IF SAM_TRACE */
                            if (saTrace) {
                                tawk("S2    Adding threat " + eSite(j) + " divert 1 " + (string) div1 + " as candidate");
                            }
/* END SAM_TRACE */
                        }
                        if (div2 != ZERO_VECTOR) {
                            divCand += div2;
                            divCandSite += j;
/* IF SAM_TRACE */
                            if (saTrace) {
                                tawk("S2    Adding threat " + eSite(j) + " divert 2 " + (string) div1 + " as candidate");
                            }
/* END SAM_TRACE */
                      }
                    }

                    /*  If we have found any candidate diverts, choose the
                        one which makes the smallest angle with the direct
                        course to the destination.  */

//llOwnerSay("S2 Candidate diverts: " + llList2CSV(divCand));
                    integer n = llGetListLength(divCand);

                    if (n > 0) {
                        float divAng = 3 * PI;
/* IF SAM_TRACE */
                        if (saTrace) {
                            tawk("S2 Divert candidates:");
                        }
/* END SAM_TRACE */

                        for (j = 0; j < n; j++) {
                            vector divj = llList2Vector(divCand, j);
                            float dang = llVecMag(llVecNorm(divj) % tbearn);
/* IF SAM_TRACE */
                            if (saTrace) {
                                tawk("S2    " + (string) (j + 1) + " " + eSite(llList2Integer(divCandSite, j)) +
                                    "  " + (string) divj + "  Ang " + (string) (dang * RAD_TO_DEG));
                            }
/* END SAM_TRACE */
                            if (dang < divAng) {
                                divAng = dang;
                                divertVec = divj;
                                closestSite = llList2Integer(divCandSite, j);
                            }
                        }
                        integer x = closestSite * samSitesN;
                        vector sposa = (llList2Vector(samSites, x + 1) * REGION_SIZE) +
                                       llList2Vector(samSites, x + 2);
                        vector sposi = sposa;
                        sposi.z = 0;
                        vector sbear = sposi - aposi;       // Vector from our position to site
                        closestThreat = llVecMag(sbear);
/* IF SAM_TRACE */
                        if (saTrace) {
                            tawk("S2 Best diversion site " + eSite(closestSite) + " range " + (string) closestThreat + " vec " + (string) divertVec + " angle " + (string) (divAng * RAD_TO_DEG));
                        }
/* END SAM_TRACE */
                    } else {
/* IF SAM_TRACE */
                        if (saTrace) {
                            tawk("S2 No solution found!  Manual evasion required.");
                        }
/* END SAM_TRACE */
                    }
/* IF SAM_TRACE */
                        if (saTrace) {
                            tawk("\n- - - - - - - - - - -\n");
                        }
/* END SAM_TRACE */
                }
            }
        }

        /*  If a diversion is required, compute the waypoint to the
            closer edge of the threat circle and return its
            grid and region co-ordinates.  */

        if (closestSite >= 0) {
            vector wposi = posG + posR + divertVec;
            vector wposG = < llFloor(wposi.x / REGION_SIZE), llFloor(wposi.y / REGION_SIZE), 0 >;
            vector wposR = wposi - (wposG * REGION_SIZE);
            divert = [
                closestSite + 1,            // Index of closest threat
                closestThreat,              // Range to closest threat
                wposG,                      // Grid co-ordinates of waypoint
                wposR,                      // Region co-ordinates of waypoint
                llList2String(samSites, (closestSite * samSitesN) + 5)  // Label of closest threat site
            ];
            if (saTrace) {
                tr += ef("\nDivert: " + llList2CSV(divert));
            }
        }
        if (saTrace) {
            tawk(tr);
        }
        return divert;
    }

    default {

        //  When we're instantiated, reset script

        on_rez(integer num) {
            llResetScript();
        }

        //  At state entry, start monitoring the command chat channel

        state_entry() {
            owner = llGetOwner();
            samSites = [];
/* IF ROCKET  */
            lSounds = findLinkNumber("Nosecone");
/* END ROCKET */
/* IF UFO
            lSounds = findLinkNumber("Saucer bottom");
/* END UFO */
        }

        //  Receipt of messages from scripts in this link set

        link_message(integer sender, integer num, string str, key id) {
//tawk("SAM Sites message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_SA_INIT (90): Initialise SAM avoidance

            if (num == LM_SA_INIT) {

            //  LM_SA_RESET (91): Reset script

            } else if (num == LM_SA_RESET) {
                llResetScript();

            //  LM_SA_STAT (92): Report status

            } else if (num == LM_SA_STAT) {
                string stat = "SAM site avoidance:  Range: " + ef((string) samRange) + "\n";
                stat += "    Trace: " + eOn(saTrace) + "\n";
                stat += "    Vehicle clearance margin: " + ef((string) samMargin) + "\n";

                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)\n";
                whoDat = id;
                tawk(stat);
                listSites("    ");

            //  LM_SA_COMMAND (94): Process command from chat

            } else if (num == LM_SA_COMMAND) {
                //  First two characters are scriptActive flag and comma
                scriptActive = (integer) llGetSubString(str, 0, 0);
                str = llGetSubString(str, 2, -1);
                integer stat = processCommand(id, str);
                //  If the command is synchronous, report status immediately
                if (scriptActive) {
                    if (stat != DEFER) {
                        llMessageLinked(LINK_THIS, LM_SA_COMPLETE, (string) stat, id);
                        whoDat = NULL_KEY;
                    }
                }

            //  LM_SA_PROBE (96): Probe for SAM threats

            } else if (num == LM_SA_PROBE) {
                list args = llJson2List(str);
                list div = threatScan(
                    (vector) llList2String(args, 0),    // Grid position
                    (vector) llList2String(args, 1),    // Region position
                    (vector) llList2String(args, 2),    // Grid destination
                    (vector) llList2String(args, 3));   // Region destination
                llMessageLinked(LINK_THIS, LM_SA_DIVERT,
                    llList2Json(JSON_ARRAY, div), id);

            //  LM_PI_PILOT (27): Set pilot agent key

            } else if (num == LM_PI_PILOT) {
                agent = id;


            //  LM_TR_SETTINGS (120): Set trace modes

            } else if (num == LM_TR_SETTINGS) {
                saTrace = (llList2Integer(llJson2List(str), 0) & LM_TR_S_SAM) != 0;

            }
        }

        //  Listen for impact messages from SAM sites

        listen(integer channel, string name, key id, string message) {
            if (channel == siteChannel) {
                if (llGetSubString(message, 0, 0) == "[") {
                    list msg = llJson2List(message);
                    string ccmd = llList2String(msg, 0);

                    //  IMPACT:  Impact report from SAM site

                    if (ccmd == "IMPACT") {
                        //  Report SAM impact to Pilotage
                        llMessageLinked(LINK_THIS, LM_PI_FIRE,
                            "SAM:" + impactAction + ":" +
                            llList2String(msg, 2), NULL_KEY);
                        if (impactAction != "ig") {
                            llMessageLinked(lSounds, LM_SO_FLASH, "", NULL_KEY);
                        }
                    }
                }
            }
        }


        //  Dataserver: receive region look-up query information

        dataserver(key id, string reply) {
            if (id == regionQ) {
                if (stateQ == 1) {
                    //  Query for region valid and up/down status
                    if (reply == "up") {
                        stateQ++;
                        regionQ = llRequestSimulatorData(rnameQ, DATA_SIM_POS);
                    } else {
                        stateQ = 0;
                        tawk("SAM site region " + rnameQ + " is " + reply + ".");
                        destRegion = rnameQ = "";
                        llMessageLinked(LINK_THIS, LM_SA_COMPLETE, (string) FALSE, whoDat);
                        whoDat = NULL_KEY;
                    }
                } else if (stateQ == 2) {
                    //  Query for region grid co-ordinates
                    vector gridc = ((vector) reply) / REGION_SIZE;
                    destRegion = rnameQ;
                    destGrid = gridc;
                    if (samLabel == "") {
                        samLabel = ef(destRegion + "(" + (string) destRegc.x + ", " +
                                      (string) destRegc.y + ")");
                    }
                    tawk("SAM site: " + destRegion + " (" +
                        (string) ((integer) llRound(destRegc.x)) + ", " +
                        (string) ((integer) llRound(destRegc.y)) + ", " +
                        (string) ((integer) llRound(destRegc.z)) + ")");
//tawk(ef("SAM site " + samLabel + ": region " + destRegion + " grid co-ordinates: " + (string) destGrid + " local: " + (string) destRegc));
                    samSites += [ rnameQ, destGrid, destRegc, samRad, samAlt, samLabel ];
                    stateQ = 0;
                    rnameQ = "";
                    if (scriptActive) {
                        llMessageLinked(LINK_THIS, LM_SA_COMPLETE, (string) TRUE, whoDat);
                    }
                    whoDat = NULL_KEY;
                }
            }
        }

        /*  Sensor: detect SAM Site emulators placed within the region.

            This event processes detection of test SAM site emulators
            placed within the region for debugging and activated via
            the "Set SAM scan" command.  For each object named "SAM site"
            (the name must be precisely that), a SAM site is defined at
            that object's position within the region, with its label,
            threat radius, and threat height taken from the object's
            description as:
                "Label" radius height
            As with the Set SAM site command, if the label is omitted,
            one will be generated from the region name and co-ordinates
            within the region.

            The list of SAM sites detected by the scan replaces any
            previously specified by any means.  */

        sensor(integer ndet) {
            integer i;

            if (ndet == 0) {
                tawk("No SAM sites detected.");
                return;
            }

            if (ndet >= 16) {
                tawk("Warning: 16 SAM sites were detected.  If more than 16\n" +
                     "   sites exist, some will not have been found.");
            }

            samSites = [ ];                     // Clear existing SAM sites

            destRegion = llGetRegionName();     // All sites are within our region
            destGrid = llGetRegionCorner() / 256;

            for (i = 0; i < ndet; i++) {
                key k = llDetectedKey(i);
                list det = llGetObjectDetails(k,
                    [   OBJECT_DESC,
                        OBJECT_POS ]);
                string desc = llList2String(det, 0);
                destRegc = llList2Vector(det, 1);

                list args = llParseString2List(desc, [" "], []);
                string l = llList2String(args, 0);
                samLabel = "";
                //  If the first argument begins with a quote, parse and remove label
                if (llGetSubString(l, 0, 0) == "\"") {
                    samLabel = llGetSubString(l, 1, -1);
                    args = llDeleteSubList(args, 0, 0);
                    while (llGetSubString(samLabel, -1, -1) != "\"") {
                        samLabel += " " + llList2String(args, 0);
                        args = llDeleteSubList(args, 0, 0);
                    }
                    samLabel = llGetSubString(samLabel, 0, -2);
                }
                samRad = (float) llList2String(args, 0);            // Threat radius
                samAlt = (float) llList2String(args, 1);            // Threat altitude
                if (samLabel == "") {
                    samLabel = ef(destRegion + "(" + (string) destRegc.x + ", " +
                                  (string) destRegc.y + ")");
                }
//llOwnerSay("SAM Site " + (string) (i + 1) + " pos " + (string) destRegc + " desc " + desc +
//    " label \"" + samLabel + "\" rad " + (string) samRad + " alt " + (string) samAlt);
                samSites += [ destRegion, destGrid, destRegc, samRad, samAlt, samLabel ];
            }
        }

    }
