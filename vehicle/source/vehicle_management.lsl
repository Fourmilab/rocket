    /*

           Fourmilab Rocket Vehicle Management

                    by John Walker

    */

/* IF ROCKET  */
    integer commandChannel = 1633;  // Command channel in chat
/* END ROCKET */
/* IF UFO
    integer commandChannel = 1947;  // Command channel in chat
/* END UFO */
    integer commandH;           // Handle for command channel
    key whoDat = NULL_KEY;      // Avatar who sent command
    integer restrictAccess = 2; // Access restriction: 0 none, 1 group, 2 owner
    integer echo = TRUE;        // Echo chat and script commands ?
    integer trace = TRUE;       // Trace operation ?
    integer showPanel = TRUE;   // Show control panel (floating text)

    string helpFileName = "Fourmilab Rocket User Guide"; // Help notecard name

    float volume = 1;           // Sound volume
    vector smokeColour = <0.75, 0.75, 0.75>;    // Smoke trail colour
    float smokeAlpha = 1;       // Smoke trail transparency (1 = solid)

    key owner;                  // UUID of owner
    key agent;                  // UUID of agent sitting on control seat

    float X_THRUST = 20;        // Thrust along X axis
    float Z_THRUST = 15;        // Thrust along Y axis

    //  Autopilot settings

    integer autoEngaged = FALSE; // Is autopilot engaged ?
    float autoAltTolerance = 3; // Autopilot altitude tolerance, metres
    float autoRangeTolerance = 3; // Autopilot range tolerance, metres
    float autoCruiseAlt = 120;  // Autopilot cruise altitude, above terrain
    float autoRange = 0;        // Current range to destination
    integer autoLandEnable = TRUE; // Enable automatic landing ?
    integer autoLand = FALSE;   // Automatic landing in progress
    integer autoSuspendExp = 0; // Time autopilot suspend expires

    //  Terrain following settings

    integer tfObstacles = TRUE; // Fly up to avoid obstacles in path ?

    //  Script processing

    integer scriptActive = FALSE;   // Are we reading from a script ?
    integer scriptSuspend = FALSE;  // Suspend script execution for asynchronous event

    //  Region queries

    integer REGION_SIZE = 256;  // Size of region in metres
    string rnameQ;              // Region name being queried
    key regionQ = NULL_KEY;     // Query region handle
    integer stateQ = 0;         /* Query state:
                                        0   Idle
                                        1   Requesting status
                                        2   Requesting grid position
                                        3   Requesting region name from grid position */
    key gridsurvQ = NULL_KEY;   // Region name from grid survey query handle
    integer gridsurvR;          // Radius of random region survey request
    integer gridsurvN = 5;      // Retries searching for extant random region
    integer gridsurvC;          // Random region search retry counter

    string destRegion = "";     // Region name of destination
    vector destGrid;            // Grid co-ordinates of destination
    vector destRegc;            // Destination co-ordinates within region

    string startRegion = "";    // Region name of start
    vector startGrid;           // Grid co-ordinates of start position
    vector startRegc;           // Start co-ordinates within region

    list destMark = [ ];        // Marked destinations

    //  Link indices within the object

    integer lSaddle;            // Nosecone
/* IF ROCKET  */
    integer lNozzle;            // Exhaust nozzle
/* END ROCKET */

    /*  The following sets where the pilot (first to be
        seated) and passenger (second to board) sit and
        the camera angle from which they observe when in
        flight.  */

    /*  Link message command codes

        Note: we declare all messages of all scripts below as a
        reference.  Those not used in this script are commented
        out.  */

    //  Vehicle Auxiliary messages
    integer LM_VX_INIT = 10;            // Initialise
    integer LM_VX_RESET = 11;           // Reset script
    integer LM_VX_STAT = 12;            // Print Vehicle Management status
//  integer LM_VX_PISTAT = 13;          // Print Pilotage status
//  integer LM_VX_PIPANEL = 14;         // Display pilot's control panel
//  integer LM_VX_HEARTBEAT = 15;       // Request heartbeat

    //  Pilotage messages
//  integer LM_PI_INIT = 20;            // Initialise
    integer LM_PI_RESET = 21;           // Reset script
//  integer LM_PI_STAT = 22;            // Print status
    integer LM_PI_DEST = 23;            // Set destination
    integer LM_PI_SETTINGS = 24;        // Update pilotage settings
    integer LM_PI_ENGAGE = 25;          // Engage/disengage autopilot
    integer LM_PI_FIRE = 26;            // Fire weapon / handle impact
    integer LM_PI_PILOT = 27;           // Pilot sit / unsit
    integer LM_PI_TARGCLR = 28;         // Clear target statistics
    integer LM_PI_MENDCAM = 29;         // Mend camera tracking

    //  Region Crossing messages
//  integer LM_RX_INIT = 30;            // Initialise vehicle
    integer LM_RX_RESET = 31;           // Reset script
//  integer LM_RX_STAT = 32;            // Print status
    integer LM_RX_LOG = 33;             // Log message
//  integer LM_RX_CHANGED = 34;         // Region or link changed

    //  Sounds Messages
//  integer LM_SO_INIT = 40;            // Initialise
    integer LM_SO_RESET = 41;           // Reset script
//  integer LM_SO_STAT = 42;            // Print status
//  integer LM_SO_PLAY = 43;            // Play sound
//  integer LM_SO_PRELOAD = 44;         // Preload sound
//  integer LM_SO_FLASH = 45;           // Explosion particle effect

    //  Script Processor messages
    integer LM_SP_INIT = 50;            // Initialise
    integer LM_SP_RESET = 51;           // Reset script
//  integer LM_SP_STAT = 52;            // Print status
    integer LM_SP_RUN = 53;             // Enqueue script as input source
    integer LM_SP_GET = 54;             // Request next line from script
    integer LM_SP_INPUT = 55;           // Input line from script
    integer LM_SP_EOF = 56;             // Script input at end of file
    integer LM_SP_READY = 57;           // Script ready to read
    integer LM_SP_ERROR = 58;           // Requested operation failed
    integer LM_SP_GOTO = 59;            // Go to line in script

    //  Passengers messages
//  integer LM_PA_INIT = 60;            // Initialise
    integer LM_PA_RESET = 61;           // Reset script
//  integer LM_PA_STAT = 62;            // Print status
//  integer LM_PA_SIT = 63;             // Passenger sits on vehicle
//  integer LM_PA_STAND = 64;           // Passenger stands, leaving vehicle

    //  Terrain Following messages
//  integer LM_TF_INIT = 70;            // Initialise
    integer LM_TF_RESET = 71;           // Reset script
//  integer LM_TF_STAT = 72;            // Print status
    integer LM_TF_ACTIVATE = 73;        // Turn terrain following on or off
// integer LM_TF_TERRAIN = 74;          // Report terrain height to client

    //  SAM Sites messages
//  integer LM_SA_INIT = 90;            // Initialise
    integer LM_SA_RESET = 91;           // Reset script
//  integer LM_SA_STAT = 92;            // Print status
//  integer LM_SA_ACTIVATE = 93;        // Turn SAM avoidance on or off
    integer LM_SA_COMMAND = 94;         // Process command from chat or script
    integer LM_SA_COMPLETE = 95;        // Chat command processing complete
// integer LM_SA_PROBE = 96;            // Probe for threats
// integer LM_SA_DIVERT = 97;           // Diversion temporary waypoint advisory

    //  Vehicle Management messages
    integer LM_VM_TRACE = 113;          // Set trace message level


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

    //  tawk  --  Send a message to the interacting user in chat

    tawk(string msg) {
        if (whoDat == NULL_KEY) {
            //  No known sender.  Say in nearby chat.
            llSay(PUBLIC_CHANNEL, msg);
        } else {
            /*  While debugging, when speaking to the owner, use llOwnerSay()
                rather than llRegionSayTo() to avoid the risk of a runaway
                blithering loop triggering the gag which can only be removed
                by a region restart.  */
            if (owner == whoDat) {
                llOwnerSay(msg);
            } else {
                llRegionSayTo(whoDat, PUBLIC_CHANNEL, msg);
            }
        }
    }

    //  max  --  Maximum of two float arguments

    float max(float a, float b) {
        if (a > b) {
            return a;
        } else {
            return b;
        }
    }

    /*  scriptResume  --  Resume script execution when asynchronous
                          command completes.  */

    scriptResume() {
        if (scriptActive) {
            if (scriptSuspend) {
                scriptSuspend = FALSE;
                llMessageLinked(LINK_THIS, LM_SP_GET, "", NULL_KEY);
tawk("Script resumed.");
            }
        }
    }

    //  autoEngageUpdate  --  Update autopilot engage status

    autoEngageUpdate() {
        llMessageLinked(LINK_THIS, LM_PI_ENGAGE,
            llList2Json(JSON_ARRAY, [ autoEngaged, autoLand, autoLandEnable,
                autoSuspendExp, scriptActive, scriptSuspend ]), whoDat);
    }

    //  updatePilotageSettings  --  Update settings relevant to the Pilotage module

    updatePilotageSettings() {
        llMessageLinked(LINK_THIS, LM_PI_SETTINGS,
            llList2Json(JSON_ARRAY, [ autoCruiseAlt,            // 0: Cruise altitude
                                      autoAltTolerance,         // 1: Altitude tolerance
                                      autoRangeTolerance,       // 2: Range tolerance
                                      smokeColour,              // 3: Smoke colour
                                      smokeAlpha,               // 4: Smoke transparency
                                      volume,                   // 5: Engine sound volume
                                      showPanel,                // 6: Show control panel ?
                                      X_THRUST,                 // 7: X thrust
                                      Z_THRUST,                 // 8: Z thrust
                                      restrictAccess,           // 9: Access restriction: owner, group, public
                                      tfObstacles               // 10: Terrain following: avoid obstacles ?
                                    ]),
            whoDat);

    }

    //  showScripts  --  Show status of scripts in inventory

    showScripts() {
        integer nos = llGetInventoryNumber(INVENTORY_SCRIPT);
        integer i;
        do {
            string scriptName = llGetInventoryName(INVENTORY_SCRIPT, i);

            string sstate = "stopped";
            if (llGetScriptState(scriptName)) {
                sstate = "running";
            }

            tawk("Script " + scriptName + ": " + sstate);
        } while (++i < nos);
    }

    //  checkAccess  --  Check if user has permission to send commands

    integer checkAccess(key id) {
        return (restrictAccess == 0) ||
               ((restrictAccess == 1) && llSameGroup(id)) ||
               (id == llGetOwner());
    }

    //  rRange  --  Choose a random number within a specified range

    float rRange(string r, float mx) {
        float l = 0;
        float h = mx;

        r = llStringTrim(r, STRING_TRIM);
        if (r != "") {
            integer sep = llSubStringIndex(r, "-");
            if (sep < 0) {
                l = h = (integer) r;
            } else {
                l = (integer) llGetSubString(r, 0, sep - 1);
                h = (integer) llGetSubString(r, sep + 1, -1);
            }
        }
        float v = llRound(l + llFrand(h - l));
//llOwnerSay("rRange(" + r + ")   [" + (string) l + ", " + (string) h + "] = " + (string) v);
        return v;
    }

    /*  randReg  --  Generate co-ordinates of random region gridsurvR
                     from our current position.  Returns a REG(x,y)
                     location with the grid co-ordinates chosen.  */

    string randReg() {
        vector regcent = llGetRegionCorner() +
            (< REGION_SIZE, REGION_SIZE, 0> / 2);
        vector regdest = regcent +
            (< llFrand(REGION_SIZE) * (gridsurvR * 2),
               llFrand(REGION_SIZE) * (gridsurvR * 2), 0 > -
             < REGION_SIZE * gridsurvR, REGION_SIZE * gridsurvR, 0 >);
//llOwnerSay("regcent " + (string) regcent + "  regdest " + (string) regdest);
        return "REG(" + (string) ((integer) llRound(regdest.x)) + "," +
            (string) ((integer) llRound(regdest.y)) + ")";
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
//  Temporary shortcuts for destinations used in testing
if (dest == "c") {              // Castle
    dest = "http://maps.secondlife.com/secondlife/Fourmilab/90/68/101";
} else if (dest == "t") {       // Target
    dest = "http://maps.secondlife.com/secondlife/Fourmilab/121/135/25";
} else if (dest == "a") {       // Animats
    dest = "http://maps.secondlife.com/secondlife/Reeds%20Landing/152/190/23";
} else if (dest == "e") {       // Empty Quarter
    dest = "http://maps.secondlife.com/secondlife/Fourmilab/227/178/26";
} else if (dest == "h") {       // Houseboat
    dest = "http://maps.secondlife.com/secondlife/Backhill/134/101/22";
} else if (dest == "d") {       // Denby
    dest = "http://maps.secondlife.com/secondlife/Denby/219/47/33";
} else if (dest == "l") {       // Lighthouse
    dest = "http://maps.secondlife.com/secondlife/Fourmilab/87/212/32";
} else if (dest == "v") {       // Villa
    dest = "http://maps.secondlife.com/secondlife/Fourmilab/186/65/26";
}
        if (llSubStringIndex(dest, "http://") >= 0) {
            /*  SLUrl like:
                "http://maps.secondlife.com/secondlife/Fourmilab/120/122/28" */
            list url = llParseString2List(dest, [ "/" ], []);
            return [ llUnescapeURL(llList2String(url, 3)),
                     < llList2Float(url, 4), llList2Float(url, 5), llList2Float(url, 6) > ];

        } else if (llSubStringIndex(dest, "secondlife://") >= 0) {
            /*  SLUrl like:
                "secondlife"//Fourmilab/120/122/28" */
            list url = llParseString2List(dest, [ "/" ], []);
            return [ llUnescapeURL(llList2String(url, 1)),
                     < llList2Float(url, 2), llList2Float(url, 3), llList2Float(url, 4) > ];

        } else if (llSubStringIndex(dest, "here://") >= 0) {
            /*  Here specification:
                "here://"  */
            return [ llGetRegionName(), llGetPos() ];

        } else if (llSubStringIndex(dest, "mark://") >= 0) {
            /*  Mark specified by its name:
                "mark://name"  */
            list url = llParseString2List(dest, [ "/" ], []);
            string mname = llList2String(url, 1);
            integer i;
            integer ll = llGetListLength(destMark);

            for (i = 0; i < ll; i += 3) {
                if (mname == llList2String(destMark, i)) {
                    return [ llList2String(destMark, i + 1),
                             llList2Vector(destMark, i + 2) ];
                }
            }
            tawk("Mark \"" + mname + "\" not found.");
            return [ ] ;

        } else if (llSubStringIndex(dest, "random://") >= 0) {
            /*  "random://reg/xl-xh/yl-yh/zl-zy"  Random location
                    reg     ./0/null = current region   n within n adjacent regions
                    al-ah   low and high limits on axes within current region  */
            list url = llParseStringKeepNulls(dest, [ "/" ], []);
            string reg = llList2String(url, 2);
            float xr = rRange(llList2String(url, 3), REGION_SIZE);
            float yr = rRange(llList2String(url, 4), REGION_SIZE);
            //  Hack: if no Z range specified, fix at 50 metres
            float zr = 50;
            if (llList2String(url, 5) != "") {
                zr = rRange(llList2String(url, 5), 4096);
            }
            if ((reg == ".") || (reg == "0") || (reg == "")) {
                //  Destination is within the current region
                reg = llGetRegionName();
            } else {
                //  Specification by adjacent region radius
                gridsurvR = (integer) reg;
                if (gridsurvR <= 0) {
                    tawk("Invalid random region radius " + reg);
                    return [ ];
                } else {
                    reg = randReg();
                }
            }
            return [ reg, < xr, yr, zr > ];

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

    //  onOff  --  Parse an on/off parameter

    integer onOff(string param) {
        if (abbrP(param, "on")) {
            return TRUE;
        } else if (abbrP(param, "of")) {
            return FALSE;
        } else {
            tawk("Error: please specify on or off.");
            return -1;
        }
    }

    //  scriptName  --  Extract script name from Set script command

    string scriptName(string subcmd, string lmessage, string message) {
        integer dindex = llSubStringIndex(lmessage, subcmd);
        dindex += llSubStringIndex(llGetSubString(lmessage, dindex, -1), " ");
        dindex += llSubStringIndex(llGetSubString(lmessage, dindex, -1),subcmd);
        dindex += llSubStringIndex(llGetSubString(lmessage, dindex, -1), " ");
        return llStringTrim(llGetSubString(message, dindex, -1), STRING_TRIM);
    }

    //  processCommand  --  Process a command

    integer processCommand(key id, string message, integer fromScript) {

        if (!checkAccess(id)) {
            llRegionSayTo(id, PUBLIC_CHANNEL,
                "You do not have permission to control this object.");
            return FALSE;
        }

        whoDat = id;            // Direct chat output to sender of command

        /*  If echo is enabled, echo command to sender unless
            prefixed with "@".  The command is prefixed with ">>"
            if entered from chat or "++" if from a script.  */

        integer echoCmd = TRUE;
        if (llGetSubString(llStringTrim(message, STRING_TRIM_HEAD), 0, 0) == "@") {
            echoCmd = FALSE;
            message = llGetSubString(llStringTrim(message, STRING_TRIM_HEAD), 1, -1);
        }
        if (echo && echoCmd) {
            string prefix = ">> ";
            if (fromScript) {
                prefix = "++ ";
            }
            tawk(prefix + message);                 // Echo command to sender
        }

        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments
        integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command

        //  Access who                  Restrict chat command access to public/group/owner

        if (abbrP(command, "ac")) {
            string who = llList2String(args, 1);

            if (abbrP(who, "p")) {          // Public
                restrictAccess = 0;
            } else if (abbrP(who, "g")) {   // Group
                restrictAccess = 1;
            } else if (abbrP(who, "o")) {   // Owner
                restrictAccess = 2;
            } else {
                tawk("Unknown access restriction \"" + who +
                    "\".  Valid: public, group, owner.\n");
                return FALSE;
            }
            updatePilotageSettings();

        /*  Channel n                   Change command channel.  Note that
                                        the channel change is lost on a
                                        script reset.  */
        } else if (abbrP(command, "ch")) {
            integer newch = (integer) llList2String(args, 1);
            if ((newch < 2)) {
                tawk("Invalid channel " + (string) newch + ".");
                return FALSE;
            } else {
                llListenRemove(commandH);
                commandChannel = newch;
                commandH = llListen(commandChannel, "", NULL_KEY, "");
                tawk("Listening on /" + (string) commandChannel);
            }

        //  Clear                       Clear chat for debugging

        } else if (abbrP(command, "cl")) {
            tawk("\n\n\n\n\n\n\n\n\n\n\n\n\n");

        //  Drop or Fire                Drop the bomb

        } else if (abbrP(command, "dr") || abbrP(command, "fi")) {
            llMessageLinked(LINK_THIS, LM_PI_FIRE, "FIRE", NULL_KEY);

        //  Echo text                   Send text to sender

        } else if (abbrP(command, "ec")) {
            integer dindex = llSubStringIndex(lmessage, command);
            integer doff = llSubStringIndex(llGetSubString(lmessage, dindex, -1), " ");
            string emsg = " ";
            if (doff >= 0) {
                emsg = llStringTrim(llGetSubString(message, dindex +
                           llSubStringIndex(llGetSubString(lmessage, dindex, -1),
                               " "), -1), STRING_TRIM);
            }
            tawk(emsg);

        //  Help                        Give help information

        } else if (abbrP(command, "he")) {
            llGiveInventory(id, helpFileName);      // Give requester the User Guide notecard

        //  Mend camera                 Mend disruption

        } else if (abbrP(command, "me")) {
            string param = llList2String(args, 1);

            //  Camera
            if (abbrP(param, "ca")) {
                llMessageLinked(LINK_THIS, LM_PI_MENDCAM, "", whoDat);
            //  Pilotage
            } else if (abbrP(param, "pi")) {
                llSetScriptState("Pilotage", FALSE);
                llSleep(1);
                llSetScriptState("Pilotage", TRUE);
                llSleep(1);
                llResetOtherScript("Pilotage");
                llSleep(1);
                showScripts();
            }

        //  Restart                     Perform a hard restart (reset script)

        } else if (abbrP(command, "re")) {
            llResetScript();            // Note that all global variables are re-initialised
            llMessageLinked(LINK_THIS, LM_PI_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_PA_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_RX_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_SP_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_TF_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_VX_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_SA_RESET, "", NULL_KEY);
            llMessageLinked(LINK_THIS, LM_SO_RESET, "", NULL_KEY);

        //  Set                         Set simulation parameter

        } else if (abbrP(command, "se")) {
            string param = llList2String(args, 1);
            string svalue = llList2String(args, 2);
            float value = (float) svalue;
//llOwnerSay("Set " + param + " " + svalue);

            //  Autopilot on/off/altitude n/land

            if (abbrP(param, "au")) {
                if (abbrP(svalue, "on")) {              // On
                    if (destRegion != "") {
                        startRegc = llGetPos();         // Save start location within region
                        startRegion =  llGetRegionName();
                        startGrid = llGetRegionCorner();
//tawk("Start region " + startRegion + " grid co-ordinates: " + (string) startGrid + " local: " + (string) startRegc);
                        autoEngaged = TRUE;
                        autoLand = FALSE;               // We're not landing
                        autoSuspendExp = 0;             // We are not suspended
                        scriptSuspend = TRUE;           // Suspend script while en route
                        autoEngageUpdate();
                        llMessageLinked(LINK_THIS, LM_TF_ACTIVATE,
                            llList2Json(JSON_ARRAY, [ 1, 1.0, 0 ]) , NULL_KEY);
tawk("Autopilot engaged.");
//tawk("Script suspend.");
                    } else {
                        tawk("No destination set.");
                        return FALSE;
                    }
                } else if (abbrP(svalue, "of")) {       // Off
                    autoDisengage();
                } else if (abbrP(svalue, "al")) {       // Altitude n
                    float n = (float) llList2String(args, 3);
                    if (n > 0) {
                        autoCruiseAlt = n;
                        updatePilotageSettings();
                    } else {
                        tawk("Invalid altitude.");
                        return FALSE;
                    }
                } else if (abbrP(svalue, "la")) {   // Land
                    if ((argn == 3) || abbrP(llList2String(args, 3), "no")) {
                        //  Now, or no argument
                        if (agent != NULL_KEY) {
                            if (!autoEngaged) {
                                //  Set destination to current location
                                destRegc = llGetPos();
                                destRegc.z = max(llGround(ZERO_VECTOR), llWater(ZERO_VECTOR));
                                destRegion =  llGetRegionName();
                                destGrid = llGetRegionCorner();
                                autoEngaged = TRUE;
                                scriptSuspend = TRUE;       // Suspend any running script
                                llMessageLinked(LINK_THIS, LM_PI_DEST,
                                    llList2Json(JSON_ARRAY, [ destRegion, destGrid, destRegc ]), agent);
//tawk("Script suspend.");
                            }
                            autoLand = TRUE;
                            autoSuspendExp = 0;
                            autoEngageUpdate();
                        }
                    } else {        // On or Off
                        autoLandEnable = onOff(llList2String(args, 3));
                        autoEngageUpdate();
                        string s = "Autoland ";
                        if (autoLandEnable) {
                            s += "enabled.";
                        } else {
                            s += "disabled.";
                        }
                        tawk(s);
                    }

                    //  Mark at <name> <destination>
                    //       clear [<name>]  (default all)
                    //       list

                    } else if (abbrP(svalue, "ma")) {
                        string wvalue = llList2String(args, 3);
                        string ulmessage = llStringTrim(message, STRING_TRIM);
                        list ulargs = llParseString2List(ulmessage, [" "], []);

                        if (abbrP(wvalue, "at")) {
                            string mname = llList2String(ulargs, 4);
                            integer dindex = llSubStringIndex(ulmessage, " " + mname + " ");
                            dindex += llStringLength(mname) + 2;
                            list dl = [ ];
                            if (dindex > 0) {
                                dl = parseDestination(llGetSubString(ulmessage, dindex, -1));
                            }
                            if (dl == []) {
                                tawk("Invalid destination " + llGetSubString(ulmessage, dindex, -1));
                                return FALSE;
                            } else {
                                destMark += mname;
                                destMark += dl;
                            }
                        } else if (abbrP(wvalue, "cl")) {
                            if (argn < 5) {
                                destMark = [ ];
                            } else {
                                string mname = llList2String(ulargs, 4);
                                integer i;
                                integer ll = llGetListLength(destMark);
                                integer found = FALSE;

                                for (i = 0; i < ll; i += 3) {
                                    if (mname == llList2String(destMark, i)) {
                                        destMark = llDeleteSubList(destMark, i, i + 2);
                                        i = ll * 3;
                                        found = TRUE;
                                    }
                                }
                                if (!found) {
                                    tawk("Mark \"" + mname + "\" not found.");
                                }
                            }
                        } else if (abbrP(wvalue, "li")) {
                            integer ll = llGetListLength(destMark);
                            integer i;
                            
                            for (i = 0; i < ll; i += 3) {
                                tawk("  " + llList2String(destMark, i) + ": " +
                                    llList2String(destMark, i + 1) + " " +
                                    (string) llList2Vector(destMark, i + 2));
                            }
                        } else {
                            tawk("Invalid.  Set Autopilot mark at/clear/list");
                        }

                    //  Tolerance alt/range n

                    } else if (abbrP(svalue, "to")) {
                        string wvalue = llList2String(args, 3);
                        float t = (float) llList2String(args, 4);
                        if (abbrP(wvalue, "al")) {
                            autoAltTolerance = t;
                            updatePilotageSettings();
                        } else if (abbrP(wvalue, "ra")) {
                            autoRangeTolerance = t;
                            updatePilotageSettings();
                        }
else { tawk("Duh"); }
                } else {
                    tawk("Invalid.  Set Autopilot on/off/altitude n/land");
                    return FALSE;
                }

            //  Destination SLUrl/DestName

            } else if (abbrP(param, "de")) {        // Destination
                integer dindex = llSubStringIndex(lmessage, "de");
                dindex += llSubStringIndex(llGetSubString(lmessage, dindex, -1), " ");
                list dl = [ ];
                if (dindex > 0) {
                    dl = parseDestination(llGetSubString(message, dindex + 1, -1));
                }
                if (dl == []) {
                    tawk("Invalid destination " + llGetSubString(message, dindex + 1, -1));
                    return FALSE;
                } else {
                    rnameQ = llList2String(dl, 0);      // Destination region name
                    destRegion = "";                    // Mark destination unknown
                    destRegc = llList2Vector(dl, 1);    // Save location within region
                    if (llSubStringIndex(rnameQ, "REG(") == 0) {
                        /*  This is a random region destination.  Launch query
                            to obtain region name from grid co-ordinates.  */
                        integer ex = llSubStringIndex(rnameQ, ",");
                        integer ey = llSubStringIndex(rnameQ, ")");
                        integer rx = ((integer) llGetSubString(rnameQ, 4, ex - 1) / 256);
                        integer ry = ((integer) llGetSubString(rnameQ, ex + 1, ey - 1) / 256);
                        string qurl = "http://api.gridsurvey.com/simquery.php?xy=" +
                            (string) rx + "," + (string) ry + "&item=name";
                        stateQ = 3;                     // Requesting region name
                        gridsurvC = 0;                  // Set first try
                        gridsurvQ = llHTTPRequest(qurl, [ ], "");
                    } else {
                        stateQ = 1;
                        regionQ = llRequestSimulatorData(rnameQ, DATA_SIM_STATUS);
                    }
                    if (fromScript) {
                        scriptSuspend = TRUE;           // Suspend script until result arrives
                    }
//tawk("Script suspend.");
                }

            //  Echo on/off

            } else if (abbrP(param, "ec")) {
                echo = onOff(svalue);

            //  Panel on/off

            } else if (abbrP(param, "pa")) {
                showPanel = onOff(svalue);
                updatePilotageSettings();
                if (!showPanel) {
                    llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_TEXT, "", ZERO_VECTOR, 0 ]);
                }

            /*  SAM ...   SAM messages are processed by the SAM Sites script.
                          These messages all cause suspension of a script until
                          a LM_SA_COMPLETE message is received indicating it has
                          been processed, for good or ill.  Note that it is possible
                          to enter a Set SAM command from chat while a script is
                          running; such commands are run asynchronously and do not
                          affect the script, even if they are in error.  */

            } else if (abbrP(param, "sa")) {
                llMessageLinked(LINK_THIS, LM_SA_COMMAND,
                    ((string) fromScript) + "," + message, id);
                if (fromScript) {
                    scriptSuspend = TRUE;
                }

            //  Script run / stop / delete / list / loop

            } else if (abbrP(param, "sc")) {

                if (abbrP(svalue, "de")) {          // Delete script_name
                    string scrName = scriptName("de", lmessage, message);
                    llRemoveInventory(scrName);

                } else if (abbrP(svalue, "li")) {    // List
                    integer n = llGetInventoryNumber(INVENTORY_NOTECARD);
                    integer i;
                    for (i = 0; i < n; i++) {
                        string s = llGetInventoryName(INVENTORY_NOTECARD, i);
                        if (s != "") {
                            tawk("  " + (string) (i + 1) + ". " + s);
                        }
                    }

                } else if (abbrP(svalue, "ru")) {          // Run script_name
                    string scrName = scriptName("ru", lmessage, message);
                    llMessageLinked(LINK_THIS, LM_SP_RUN, scrName, whoDat);

                } else if (abbrP(svalue, "st")) {    // Stop
                    if (scriptActive) {
                        scriptActive = scriptSuspend = FALSE;
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", whoDat); // Reset Script Processor
                        if (autoEngaged) {
                            autoDisengage();
                        }
                    }
                }

            //  Smoke r g b alpha

            } else if (abbrP(param, "sm")) {
                smokeColour = < value,
                                (float) llList2String(args, 3),
                                (float) llList2String(args, 4) >;
                smokeAlpha = (float) llList2String(args, 5);
                updatePilotageSettings();

            //  Target clear

            } else if (abbrP(param, "ta")) {
                if (abbrP(svalue, "cl")) {
                    llMessageLinked(LINK_THIS, LM_PI_TARGCLR, "", whoDat);
               }

            //  Terrain obstacles on/off

            } else if (abbrP(param, "te")) {
                if (abbrP(svalue, "ob")) {
                    tfObstacles = onOff(llList2String(args, 3));
                    updatePilotageSettings();
               }

            //  Thrust horizontal/vertical/x/y n

            } else if (abbrP(param, "th")) {
                value = (float) llList2String(args, 3);
                if (abbrP(svalue, "h") || abbrP(svalue, "x")) {
                    X_THRUST = value;
                } else if (abbrP(svalue, "v") || abbrP(svalue, "z")) {
                    Z_THRUST = value;
                }
                updatePilotageSettings();

            // Trace on/off/n

            } else if (abbrP(param, "tr")) {
                if (abbrP(svalue, "on")) {
                    trace = TRUE;
                } else if (abbrP(svalue, "of")) {
                    trace = FALSE;
                } else {
                    trace = (integer) svalue;
                }
                //  Let other scripts know new trace value
                llMessageLinked(LINK_THIS, LM_VM_TRACE,
                    llList2Json(JSON_ARRAY, [ trace ]), whoDat);

            // Volume v

            } else if (abbrP(param, "vo")) {
                float oldvol = volume;
                volume = value;
                updatePilotageSettings();
                /*  If the volume transitions between 0 (off) and a
                    positive value, start or stop the engine
                    sound loop accordingly.  */
                    if ((volume == 0) && (oldvol > 0)) {
                        llStopSound();
                    } else if ((oldvol == 0) && (volume > 0)) {
                        llLoopSound("Engine flight", volume);
                   }
            } else {
                tawk("Unknown variable \"" + param +
                    "\".  Valid: autopilot, destination, echo, panel, SAM, script, smoke, trace, volume.");
                return FALSE;
            }

        //  Status                      Print current status

        } else if (abbrP(command, "st")) {
            llMessageLinked(LINK_THIS, LM_VX_STAT,
                llList2Json(JSON_ARRAY, [ autoEngaged, autoRange,
                                          llGetFreeMemory(), llGetUsedMemory(),
                                          X_THRUST, Z_THRUST, lSaddle
                                        ]),
                whoDat);

        //  Test n                      Run built-in test n

        } else if (abbrP(command, "te")) {
            integer n = (integer) llList2String(args, 1);
            if (n == 1) {
                //  Test 1      Eject passenger
                key pass = llAvatarOnLinkSitTarget(lSaddle);
                if (pass != NULL_KEY) {
                    llUnSit(pass);
                } else {
                    tawk("No passenger.");
                }
            } else if (n == 2) {
                //  Test 2      Restore permissions and controls for pilot
                llMessageLinked(LINK_THIS, 901, "", whoDat);
            } else if (n == 3) {
                //  Test 3      Restore permissions for passenger
                llMessageLinked(LINK_THIS, 902, "", whoDat);

            } else if (n == 4) {
                //  Test 4      Show script status
                showScripts();
            } else if (n == 999) {
                //  Test 999    Destroy vehicle
                llDie();
            } else {
                tawk("Test what?");
            }
        } else {
            tawk("Huh?  \"" + message + "\" undefined.  Chat /" +
                (string) commandChannel + " help for the User Guide.");
            return FALSE;
        }
        return TRUE;
    }

    //  vehicleInit  --  Initialise vehicle modes

    vehicleInit() {

        //  Initialise vehicle properties
        llMessageLinked(LINK_THIS, LM_VX_INIT, "", NULL_KEY);

        //  Start listening on the command chat channel
        commandH = llListen(commandChannel, "", NULL_KEY, "");
        llOwnerSay("Listening on /" + (string) commandChannel);

/* IF ROCKET  */
        //  Make sure nozzle glow is off
        llSetLinkPrimitiveParamsFast(lNozzle, [ PRIM_GLOW, 2, 0 ]);
/* END ROCKET */
    }

    //  autoDisengage  --  Disengage autopilot

    autoDisengage() {
        if (autoEngaged) {
            autoLand = autoEngaged = FALSE;
            autoSuspendExp = 0;
            autoEngageUpdate();
            llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION, ZERO_VECTOR);
            llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION, ZERO_VECTOR);
            llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_TEXT, "", < 0, 0, 0 >, 0 ]);
            llMessageLinked(LINK_THIS, LM_TF_ACTIVATE,
                llList2Json(JSON_ARRAY, [ 0, 1.0, 0 ]) , NULL_KEY);
llOwnerSay("Autopilot disengaged.");
            scriptResume();
        }
    }

    default {
        state_entry() {
            owner = llGetOwner();

//  Cancel any legacy prim-wide sit target and camera overrides
llSitTarget(ZERO_VECTOR, ZERO_ROTATION);
llSetCameraAtOffset(ZERO_VECTOR);
llSetCameraEyeOffset(ZERO_VECTOR);

            //  Find and save link numbers for child prims
/* IF ROCKET  */
            lSaddle = findLinkNumber("Nosecone");
            lNozzle = findLinkNumber("Nozzle");
/* END ROCKET */
/* IF UFO
            lSaddle = findLinkNumber("Fourmilab Flying Saucer");
/* END UFO */

            llSetSitText("Fly");        // Set text for Sit On menu item
            // Clear global sit position if it's been previously set
            llSitTarget(ZERO_VECTOR, ZERO_ROTATION);

            llAllowInventoryDrop(TRUE); // Allow anybody to drop script notecards

            vehicleInit();              // Initialise vehicle settings

            llMessageLinked(LINK_THIS, LM_VM_TRACE, // Announce initial trace setting
                llList2Json(JSON_ARRAY, [ trace ]), whoDat);
        }

        //  When we're instantiated, set physics off

        on_rez(integer num) {
            llSetStatus(STATUS_PHYSICS, FALSE);
            llResetScript();
        }

        /*  The listen event handler processes messages from
            our chat control channel.  */

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message, FALSE);
        }

        //  Receipt of messages from scripts in this link set

        link_message(integer sender, integer num, string str, key id) {
//llOwnerSay("Main link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  Region Crossing Messages


            //  LM_PI_PILOT (27): Pilot sit / unsit

            if (num == LM_PI_PILOT) {
                agent = id;

            //  LM_RX_LOG (33): Log message from Region Crossing

            } else if (num == LM_RX_LOG) {
                list m = llJson2List(str);
                //  If trace not set, only show Error or Fatal messages
                if (trace || (llList2Integer(m, 0) >= 3)) {
                    tawk("Region Crossing: " + llList2CSV(m));
                }

            //  Script Processor Messages

            //  LM_SP_READY (57): Script ready to read

            } else if (num == LM_SP_READY) {
                scriptActive = TRUE;
                llMessageLinked(LINK_THIS, LM_SP_GET, "", id);  // Get the first line

            //  LM_SP_INPUT (55): Next executable line from script

            } else if (num == LM_SP_INPUT) {
                if (str != "") {                // Process only if not hard EOF
                    scriptSuspend = FALSE;
                    integer stat = processCommand(id, str, TRUE); // Some commands set scriptSuspend
                    if (stat) {
                        if (!scriptSuspend) {
                            llMessageLinked(LINK_THIS, LM_SP_GET, "", id);
                        }
                    } else {
                        //  Error in script command.  Abort script input.
                        scriptActive = scriptSuspend = FALSE;
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", id);
                        tawk("Script terminated.");
                    }
                }

            //  LM_SP_EOF (56): End of file reading from script

            } else if (num == LM_SP_EOF) {
                scriptActive = FALSE;           // Mark script input complete

            //  LM_SP_ERROR (58): Error processing script request

            } else if (num == LM_SP_ERROR) {
                llRegionSayTo(id, PUBLIC_CHANNEL, "Script error: " + str);
                scriptActive = scriptSuspend = FALSE;
                llMessageLinked(LINK_THIS, LM_SP_INIT, "", id);

            //  SAM Sites Messages

            //  LM_SA_COMPLETE (95):   Processing of deferred SAM command complete

            } else if (num == LM_SA_COMPLETE) {
//llOwnerSay("LM_SA_COMPLETE " + str + "  scriptActive " + (string) scriptActive + "  scriptSuspend " + (string) scriptSuspend);
                if ((integer) str) {
                    scriptResume();
                } else {
                    //  Error in SAM command: abort any script running
                    if (scriptActive) {
                        scriptActive = scriptSuspend = FALSE;
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", id);
                        tawk("Script terminated.");
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
                        tawk("Destination region " + rnameQ + " is " + reply + ".");
                        destRegion = rnameQ = "";
                        scriptResume();
                    }
                } else if (stateQ == 2) {
                    //  Query for region grid co-ordinates
                    vector gridc = ((vector) reply) / REGION_SIZE;
                    destRegion = rnameQ;
                    destGrid = gridc;
                    tawk("Destination: " + destRegion + " (" +
                        (string) ((integer) llRound(destRegc.x)) + ", " +
                        (string) ((integer) llRound(destRegc.y)) + ", " +
                        (string) ((integer) llRound(destRegc.z)) + ")");
//tawk("Destination region " + destRegion + " grid co-ordinates: " + (string) destGrid + " local: " + (string) destRegc);
                    llMessageLinked(LINK_THIS, LM_PI_DEST,
                        llList2Json(JSON_ARRAY, [ destRegion, destGrid, destRegc ]), agent);
                    stateQ = 0;
                    rnameQ = "";
                    scriptResume();
                }
            }
        }

        //  HTTP response: grid survey query results

        http_response(key request_id, integer status, list metadata, string body) {
            if (request_id == gridsurvQ) {
                if (status == 200) {
//llOwnerSay("Region name: " + body);
                    if (llSubStringIndex(body, "Error 013") == 0) {
                        /*  If no region exists at the randomly-generated
                            co-ordinates, we will receive an Error 013
                            message from the grid survey server.  In this
                            case, we'll re-try generating a new random
                            location to see if that one exists, up to
                            gridsurvN times, after which we give up.  */
                        gridsurvC++;
                        if (gridsurvC <= gridsurvN) {
                            rnameQ = randReg();
                            integer ex = llSubStringIndex(rnameQ, ",");
                            integer ey = llSubStringIndex(rnameQ, ")");
                            integer rx = ((integer) llGetSubString(rnameQ, 4, ex - 1) / 256);
                            integer ry = ((integer) llGetSubString(rnameQ, ex + 1, ey - 1) / 256);
                            string qurl = "http://api.gridsurvey.com/simquery.php?xy=" +
                                (string) rx + "," + (string) ry + "&item=name";
//llOwnerSay("Retry " + (string) gridsurvC + " QURL " + qurl);
                            stateQ = 3;                     // Requesting region name
                            gridsurvQ = llHTTPRequest(qurl, [ ], "");
                        } else {
                            //  Retries exhausted: give up
                            stateQ = 0;
                            tawk("No active region could be found within radius " +
                                (string) gridsurvR);
                            destRegion = rnameQ = "";
                            if (scriptActive) {
                                scriptActive = scriptSuspend = FALSE;
                                llMessageLinked(LINK_THIS, LM_SP_INIT, "", whoDat);
                                tawk("Script terminated.");
                            }
                            scriptResume();
                        }
                    } else {
                        //  Valid region: proceed with region query status by name
                        rnameQ = llUnescapeURL(body);   // Region name
                        integer p;
                        //  llUnescapeURL() doesn't convert "+" to space
                        while ((p = llSubStringIndex(rnameQ, "+")) >= 0) {
                            rnameQ = llGetSubString(rnameQ, 0, p - 1) + " " +
                                llGetSubString(rnameQ, p + 1, -1);
                        }
                        stateQ = 1;
                        regionQ = llRequestSimulatorData(rnameQ, DATA_SIM_STATUS);
                    }
                } else {
//  ABORT REGION QUERY
                    stateQ = 0;
tawk("Region query failed, status " + (string) status + ".");
                    destRegion = rnameQ = "";
                    scriptResume();
                    if (scriptActive) {
                        scriptActive = scriptSuspend = FALSE;
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", whoDat);
                        tawk("Script terminated.");
                    }
                }
            }
        }
    }
