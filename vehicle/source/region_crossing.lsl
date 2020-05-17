
//  Animats
//  March 2019
//

    /*  This script is based upon the RegionRX technology developed
        by Second Life resident Animats, whose laboratory is located
        at:
            http://maps.secondlife.com/secondlife/Vallone/246/23/36
        with code published on GitHub:
            https://github.com/John-Nagle/lslutils

        The original code has been adapted here to run as an independent
        script which communicates with other scripts via link messages.
        This reduces the memory requirements for the other scripts and
        encapsulates the region crossing mechanisms here.  I may, of course,
        in the process of these modifications, introduced errors, which are
        entirely my own responsibility.  */

    //  Region crossing messages
    integer LM_RX_INIT = 30;            // Initialise vehicle
    integer LM_RX_RESET = 31;           // Reset script
    integer LM_RX_STAT = 32;            // Print status
    integer LM_RX_LOG = 33;             // Log message
    integer LM_RX_CHANGED = 34;         // Region or link changed

    //  Vehicle management messages
    integer LM_VM_TRACE = 113;          // Set trace message level

    /*  Find a linked prim from its name.  Avoids having to slavishly
        link prims in order in complex builds to reference them later
        by link number.  You should only call this once, in state_entry(),
        and then save the link numbers in global variables.  Returns the
        prim number or -1 if no such prim was found.  Caution: if there
        are more than one prim with the given name, the first will be
        returned without warning of the duplication.  */
/*
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
*/

//
//  Vehicle utilities
//

    float REGION_SIZE = 256;        // Region size in metres
//    float HUGE = 100000000000.0;    // Huge number larger than any distance
//    float TINY = 0.0001;            // Small value to prevent divide by zero
//    float MIN_SAFE_DOUBLE_REGION_CROSS_TIME = 2.0;  // Min time between double region crosses at speed
//    float MIN_BRAKE_SPEED = 0.2;    // Minimum speed we will ever brake to
    integer DRIVER_SEAT_LINK;       // Link number of driver's seat

//  Utility functions

/*
float min(float a, float b)
{   if (a < b) { return(a); } else { return(b); }}
float max(float a, float b)
{   if (a > b) { return(a); } else { return(b); }}
float abs(float a)
{   if (a > 0) { return(a); } else { return(-a); }}
*/

//
//  nearestcorner -- nearest region corner to position
//
//  Will need revision for systems with multiple region sizes
//
/*
vector nearestcorner(vector pos)
{   vector corner = <0,0,0>;
    if (pos.x*2.0 > REGION_SIZE) corner.x = REGION_SIZE;
    if (pos.y*2.0 > REGION_SIZE) corner.y = REGION_SIZE;
    return(corner);
}
*/

integer outsideregion(vector pos)                       // TRUE if outside region
{   return(pos.x < 0.0 || pos.x > REGION_SIZE || pos.y < 0.0 || pos.y > REGION_SIZE); }

//
//  regioncrossingseglength -- length of segment between next two region crossings in dir
//
//  Ignores Z direction.
//  There is a diagram of this in regioncrossing.md.
//
/*
float regioncrossingseglength(vector pos, vector dir)
{
    vector corner = nearestcorner(pos);             // nearest region corner
    vector dp = pos - corner;                       // work in coord system where corner is <0,0>
    float xcept = HUGE;                             // X intercept
    float ycept = HUGE;                             // Y intercept
    if (abs(dir.x) > TINY)                          // avoid divide by zero
    {   ycept = dp.y + dir.y * (-dp.x / dir.x); }   // Y intercept
    if (abs(dir.y) > TINY)
    {   xcept = dp.x + dir.x * (-dp.y / dir.y); }   // X intercept
    return(llSqrt(xcept*xcept + ycept*ycept));      // return segment distance
}
*/

//
//  regioncrossingprobe  --  returns length of segment between closest two next region crossings
//
//  The test is made along two test vectors some angle apart
//  Returns HUGE if not meaningful.
//  ***UNUSED*** at present
//
/*
float regioncrossingprobe(vector pos, vector dir, rotation testangle1, rotation testangle2)
{
    vector v1 = dir * testangle1;                   // need two test vectors
    vector v2 = dir * testangle2;                   //
    return(min(regioncrossingseglength(pos, v1), regioncrossingseglength(pos, v2))); // closest hit
}
*/


//  Where will a 2D XY vector from p in direction v hit a box of [0..boxsize, 0..boxsize]?
//  Returns distance. Hit point is pos + distance*norm(dir)
/*
float line_box_intersection(vector pos, vector dir, float boxsize)
{   dir.z = 0;
    pos.z = 0;
    dir = llVecNorm(dir);
    //  p = pos + dir * dist;               p is a point on the edge
    float dist1 = HUGE;                     // distance to X bound
    float dist2 = HUGE;                     // distance to Y bound
    //  Check Y axis edges
    //  p1.x = pos.x + dir.x * dist
    if (dir.x < -TINY)                      // will hit on 0 edge, p1.x = 0
    {   dist1 = -pos.x/dir.x; }             // distance to x=0 edge
    else if (dir.x > TINY)                // will hit on boxsize edge, p1.x = boxsize
    {   dist1 = (-(pos.x - boxsize))/dir.x; }   // boxsize = pos.x + dir.x * dist1
    //  Check X axis edges
    if (dir.y < -TINY)
    {   dist2 = -pos.y/dir.y; }
    else if (dir.y > TINY)
    {   dist2 = (-(pos.y - boxsize))/dir.y; }
    if (dist1 < dist2) { return(dist1);}
    return(dist2);                  // return minimum distance
}
*/
//
//  slowforregioncross -- do we need to slow down for a region crossing?
//
/*
float maxspeedforregioncross(vector pos, vector vel)
{
    float maxspeed = HUGE;                              // assume no speed limit
    vel.z = 0;                                          // XY plane only
    float speed = llVecMag(vel);                        // how fast are we going
    if (speed < TINY) { return(HUGE); }                 // slow enough that not a problem
    float disttosimcross = line_box_intersection(pos, vel, REGION_SIZE);    // dist to sim crossing
    float timetoedge = disttosimcross / speed;                    // speed to edge
    ////if (((TimerTick % 10) == 0) && (timetoedge < 1.5)) // ***TEMP DEBUG***
    ////{   llOwnerSay((string)disttosimcross + "m to region boundary at " + (string)pos + "  " + (string)speed + "m/sec."); } // ***TEMP***
    if (timetoedge < TIMER_INTERVAL*3.0)                // if very close to sim crossing and time to brake
    {   float rcseglength = regioncrossingseglength(pos, vel); // distance between next two sim crosses
        //  slow to prevent too-fast double region cross
        maxspeed = max(rcseglength / MIN_SAFE_DOUBLE_REGION_CROSS_TIME, MIN_BRAKE_SPEED);
        ////if (maxspeed < speed)
        ////{   llOwnerSay("Region crossing braking: segment length: " + (string)rcseglength +
        ////   "  speed limit: " + (string)maxspeed);  }// ***TEMP***
    }
    return(maxspeed);
}
//  posasstring -- get current position as string
string posasstring(string region, vector pos)
{
    return(region
        + " (" + (string)((integer)pos.x)
        + "," + (string)((integer)pos.y)
        + "," + (string)((integer)pos.z) + ")");
}
*/

//
//  avatardisttoseat -- distance from avatar to seat position
//
//  Used to test for sit validity.
//  Returns < 0 if not meaningful
//
float avatardisttoseat(key avatar)
{   if (avatar == NULL_KEY) { return(-1.0); }
    vector vehpos = llGetPos();
    list avatarinfo = llGetObjectDetails(avatar,
                [OBJECT_POS, OBJECT_ROOT]);
    if (llGetListLength(avatarinfo) < 1) { return(-1.0); }
    vector avatarpos = llList2Vector(avatarinfo,0);
//    key avatarroot = llList2Key(avatarinfo,1);
    return(llVecMag(avatarpos - vehpos));
}
//
//  ifnotseated  - true if avatar position is valid
//
//  Check for everything which can go wrong with the vehicle/avatar
//  relationship.
//

//integer seatedError = 0;

integer ifnotseated(key avatar, float normaldisttoseat, integer verbose)
{   integer trouble = FALSE;
    //  Check for avatar out of position
    if (avatar != NULL_KEY)
    {   float avatardist = avatardisttoseat(avatar);    // check for too far from seat
        if (avatardist > (normaldisttoseat*1.5 + 1.0) || avatardist < 0.0)
            {   trouble = TRUE;
                if (verbose) llOwnerSay("Avatar out of position: " +
                    (string)avatardist + "m from vehicle.");
            }
        integer agentinfo = llGetAgentInfo(avatar);
        if (agentinfo & (AGENT_SITTING | AGENT_ON_OBJECT) !=
            (AGENT_SITTING | AGENT_ON_OBJECT))
        {   trouble = TRUE;
            if (verbose) llOwnerSay("Avatar not fully seated.");
        }
        //  Check back link from avatar to root prim.
        list avatarinfo = llGetObjectDetails(avatar,
                [OBJECT_POS, OBJECT_ROOT]);
        key avatarroot = llList2Key(avatarinfo,1);
        if (avatarroot == NULL_KEY)
        {   trouble = TRUE;
            if(verbose) llOwnerSay("Avatar link to root is null.");
        }
        else if (avatarroot == avatar)
        {   trouble = TRUE;
            if (verbose) llOwnerSay("Avatar link to root is to avatar itself.");
        }
        else if (avatarroot != llGetKey())
        {   trouble = TRUE;
            if (verbose)
            {   llOwnerSay("Avatar link to root is wrong.");
                llOwnerSay("Avatar link to root: " +
                    (string) avatarroot + "  Veh. root: " +
                    (string) llGetKey() + "  Avatar: " +
                    (string) avatar);
            }
        }
    } else {                    // unseated
        trouble = TRUE;
        if (verbose) { llOwnerSay("Avatar not on sit target."); }
    }
/*  We can loop reporting avatar out of position link wrong,  This
    is not recoverable by any process of which I am aware.  If we
    get too many of these messages without a successful seat detection,
    destroy the vehicle so it doesn't go on blithering until something
    causes it to be returned to Lost And Found.  */
/*
if (trouble) {
    seatedError++;
    llOwnerSay("Seating error " + (string) seatedError);
    if (seatedError > 20) {
        llOwnerSay("Unrecoverable avatar seating problem.  Returning vehicle.");
//        llDie();
        llReturnObjectsByID([ llGetKey() ]);
    }
} else {
    if (seatedError > 0) {
        llOwnerSay("Recovered from seating problem after " +
            (string) seatedError + " probes.");
    }
    seatedError = 0;
}
*/
    return trouble;
}

/*
integer ifnotperms(integer permissions)
{   integer trouble = FALSE;
    //  Check for proper permissions
    integer perms = llGetPermissions(); // what perms do we have?
    if (permissions & perms != permissions)
    {   llOwnerSay("Vehicle lost permissions. Have " + (string) perms +
            " Should have " + (string) permissions);
        trouble = TRUE;
    }
    return trouble;
}
*/

//  #include "Rocket/regionrx.lsl"

//
//  regionrx -- region cross fix library
//
//  Animats
//  March, 2018
//
//    Basic settings
float TIMER_INTERVAL = 0.1;                 // check timer rate
float MAX_CROSSING_TIME = 30.0;             // stuck if crossing takes more than this long
float HOVER_START_TIME = 0.2;               // start hovering when this far in time from region cross
//integer MAX_SECS_BETWEEN_MSGS = 60;         // message at least once this often
//  Constants
integer TICK_NORMAL = 0;                    // normal tick event
integer TICK_CROSSSTOPPED = 1;              // stopped for region crossing
integer TICK_FAULT = 2;                     // fault on timer event

integer LOG_DEBUG = 0;                      // logging severity levels
integer LOG_NOTE = 1;
integer LOG_WARN = 2;
integer LOG_ERR = 3;
integer LOG_FAULT = 4;
//integer LOG_FATAL = 5;
//list LOG_SEVERITY_NAMES = ["DEBUG", "NOTE", "WARNING", "ERROR", "FAULT", "FATAL"];  // names for printing


//
//  Globals
//
//  Status during region crossing
integer     crossStopped = FALSE;
vector      crossVel = <0,0,0>;             // velocity before region crossing, to be restored later
vector      crossAngularVelocity = <0,0,0>; // always zero for now
float       crossStartTime;                 // starts at changed event, ends when avatar in place
integer     crossFault = FALSE;             // no fault yet
integer     crossHover = FALSE;             // not hovering across a region crossing
float       crossHoverHeight;               // height during region crossing
//  Global status
integer     gLogMsgLevel = LOG_DEBUG;       // display messages locally above this level
integer     gLogSerial = 0;                 // log serial number

integer     gTimerTick = 0;                 // number of timer ticks
float       gDistanceTraveled = 0.0;        // distance traveled
vector      gPrevPos = <0,0,0>;             // previous position
vector      gLastSafePos = <0,0,0>;         // last place everything was going well
integer     gRegionCrossCount = 0;          // number of regions crossed
string      gTripId = "???";                // random trip ID, for matching log messages
integer     gLastMsgTime = 0;               // time last message was sent
list        gSitters = [];                  // current sitters (keys)
list        gSitterDistances = [];          // distance to seat of sitter when seated (float)

//
//  logrx - logs to server or locally
//
logrx(integer severity, string msgtype, string msg, float val)
{
/*
    if (severity >= gLogMsgLevel)           // in-world logging
    {   llOwnerSay(llList2String(LOG_SEVERITY_NAMES,severity) + " " + posasstring(llGetRegionName(), llGetPos()) + " " + msgtype + ": " + msg + " " + (string)val);   }
    //  Remote logging. Only works if there's another script listening for LOG messages
    list logdata = [];
    gLastMsgTime = llGetUnixTime();         // time we last sent a message
    logdata = logdata + ["tripid"] + gTripId + ["severity"] + severity + ["eventtype"] + msgtype + ["msg"] + msg + ["auxval"] + val
        + ["timestamp"] + gLastMsgTime + ["serial"] + gLogSerial;
    string s = llList2Json(JSON_OBJECT, logdata);   // encode as JSON
    llMessageLinked(LINK_THIS, 0, s, "LOG"); // put message on logger script queue.
    gLogSerial++;                           // serial number within
*/

//if (severity >= gLogMsgLevel) {
//llSay(PUBLIC_CHANNEL, "RegionRX " + (string) severity + "  " + msgtype +
//      "  " + msg + "  " + (string) val);
//}
     llMessageLinked(LINK_THIS, LM_RX_LOG, llList2Json(JSON_ARRAY,
        [ severity, msgtype, msg, val ]), NULL_KEY);
}

key driverKey = NULL_KEY;                   // UUID of driver

initregionrx(integer loglevel)              // initialization - call at vehicle start
{   gRegionCrossCount = 0;
    gTimerTick = 0;
    gLogSerial = 0;                         // reset log serial number
    vector pos = llGetPos();                // get starting position
    gPrevPos = pos + llGetRegionCorner();   // global pos
    gPrevPos.z = 0.0;                       // only care about XY
    gLastSafePos = pos;                     // last safe position, region coords
    gDistanceTraveled = 0.0;
    crossFault = FALSE;                     // no crossing fault
    crossStopped = FALSE;                   // not crossing
    crossVel = <0,0,0>;                     // stationary
    crossHover = TRUE;                      // assuming hovering so we will turn hover off
                                            // trip ID is a random ID to connect messages
    gTripId = llSHA1String((string)llFrand(1.0) + (string)llGetOwner() + (string)llGetPos());
    gLogMsgLevel = loglevel;                // set logging level
    driverKey = llAvatarOnLinkSitTarget(DRIVER_SEAT_LINK);  // key of driver
    string driverdisplayname = llGetDisplayName(driverKey); // log driver name
    string drivername = llKey2Name(driverKey); // "login name / display name"
    logrx(LOG_NOTE,"STARTUP", drivername + "/" + driverdisplayname,0.0);      // log startup
    logrx(LOG_NOTE,"DRIVERKEY", (string)driverKey, 0.0); // Driver's key, for when names become changeable
}

integer updatesitters()                     // update list of sitters - internal
{
    gSitters = [];                              // rebuild list of sitters
    gSitterDistances = [];                      // and sitter distances
    integer linknum;
    integer primcount = llGetNumberOfPrims();   // do once before loop
    for (linknum = 1; linknum <= primcount; linknum++)    // check all links for sitters
    {   key avatar = llAvatarOnLinkSitTarget(linknum);
        if (avatar != NULL_KEY)                 // found a seated avatar
        {   gSitters += avatar;                 // add to avatar list
            float disttoseat = avatardisttoseat(avatar); // add initial sit distance
            gSitterDistances += disttoseat; // add initial sit distance
            string avatarname = llList2String(llGetObjectDetails(avatar, [OBJECT_NAME]),0);
            logrx(LOG_NOTE, "SITTER", "on prim #" + (string)linknum + " :" + avatarname + " distance to seat ", disttoseat);
        }
    }
    integer sittercount = llGetListLength(gSitters);
    logrx(LOG_NOTE, "RIDERCOUNT ","", (float)sittercount);
    return(sittercount);
}
//
//  handlechanged --  call this on every "changed" event
//
integer handlechanged(integer change)           // returns TRUE if any riders
{   if (change & CHANGED_REGION)                // if in new region
    {   float speed = llVecMag(llGetVel());     // get velocity
        gRegionCrossCount++;                    // tally
        gLastSafePos = llGetPos();              // position in new region
        logrx(LOG_NOTE, "CROSSSPEED", "", speed);
        if (llGetStatus(STATUS_PHYSICS))        // if physics on
        {   if (crossVel == <0,0,0>)            // if no saved pre-hover velocity (very fast driving)
            {   crossVel = llGetVel();  }       // restore this velocity after crossing
            crossAngularVelocity = <0,0,0>;     // there is no llGetAngularVelocity();
            llSetStatus(STATUS_PHYSICS, FALSE); // forcibly stop object
            crossFault = FALSE;                 // no fault yet
            crossStopped = TRUE;                // stopped during region crossing
            crossStartTime = llGetTime();       // timestamp
        } else {                                // this is bad. A partial unsit usuallly follows
            logrx(LOG_ERR, "SECONDCROSS", "second region cross started before first one completed. Cross time: ", llGetTime()-crossStartTime);
        }
    }
    if((change & CHANGED_LINK) == CHANGED_LINK)     // rider got on or off
    {
//integer sittercount = 
        updatesitters();
//llOwnerSay("RX CHANGED_LINK  sittercount " + (string) sittercount + "  DRIVER_SEAT_LINK: " + (string) DRIVER_SEAT_LINK + "  sitTarget " + (string) llAvatarOnLinkSitTarget(DRIVER_SEAT_LINK));
        if (llAvatarOnLinkSitTarget(DRIVER_SEAT_LINK) == NULL_KEY) {
//llOwnerSay("RX stop timer.");
            llSetTimerEvent(0.0);                   // no sitters, no timer
        } else if (llAvatarOnLinkSitTarget(DRIVER_SEAT_LINK) != NULL_KEY) {
//llOwnerSay("RX start timer.");
            llSetTimerEvent(TIMER_INTERVAL);        // sitter on pilot seat, run timer
        } else {
//llOwnerSay("RX: must have been a passenger.");
        }
    }
    return(llGetListLength(gSitters) > 0);          // returns TRUE if anybody on board
}

//
//  starthover --- start hovering over region crossing.  Internal
//
//  This prevents sinking or falling through unsupported region crossings.
//
starthover()
{
    if (!crossHover)                            // if not hovering
    {   llSetVehicleFloatParam(VEHICLE_HOVER_HEIGHT, crossHoverHeight);     // anti-sink
        llSetVehicleFlags(VEHICLE_FLAG_HOVER_GLOBAL_HEIGHT | VEHICLE_FLAG_HOVER_UP_ONLY);
        llSetVehicleFloatParam(VEHICLE_HOVER_TIMESCALE, 0.1);       // start hovering
        llSetVehicleFloatParam(VEHICLE_HOVER_EFFICIENCY, 1.0);      //
        crossHover = TRUE;                      //
        ////llOwnerSay("Start hovering.");
    }
}
//
//  endover  -- internal
//
endhover()
{
    if (crossHover)
    {   llRemoveVehicleFlags(VEHICLE_FLAG_HOVER_GLOBAL_HEIGHT | VEHICLE_FLAG_HOVER_UP_ONLY);     // stop hovering
        llSetVehicleFloatParam(VEHICLE_HOVER_TIMESCALE, 999.0);     // stop hovering (> 300 stops feature)
        crossHover = FALSE;
        ////llOwnerSay("Stop hovering.");
    }
}
//
//  handletimer  --  call this on every timer tick
//
integer handletimer()                               // returns 0 if normal, 1 if cross-stopped, 2 if fault
{
    gTimerTick++;                                    // count timer ticks for debug
    vector pos = llGetPos();
    vector gpos = pos + llGetRegionCorner();        // global pos
    gpos.z = 0.0;                                   // only care about XY
    gDistanceTraveled += llVecMag(gPrevPos - gpos); // distance traveled add
    gPrevPos = gpos;                                // save position

    //  Hover control -- hover when outside region and unsupported.
    //  Should help on flat terrain. Too dumb for region crossings on hills.
    if (!crossStopped)                              // don't mess with hovering if crossing-stopped
    {   vector vel = llGetVel();                    // velocity
        if (outsideregion(pos) || outsideregion(pos + vel*HOVER_START_TIME)) // if outside region or about to leave
        {   starthover();                           // start hovering
        } else {
            crossHoverHeight = pos.z;               // save last height outside hover region
            crossVel = vel;                         // restore this velocity after crossing
            endhover();                             // stop hovering if hovering
        }
        //  Ban line / object not allowed to enter region recovery.
        //  Turns physics off, moves a short distance, turns physics back on.
        if (!crossHover)                            // if not in cross stop or hover, situation is normal
        {   integer physicson = llGetStatus(STATUS_PHYSICS);    // is physics on, as it should be?
            if (!physicson)                         // physics is not on. Probably hit a ban line
            {   float movemag = llVecMag(pos - gLastSafePos);
                logrx(LOG_WARN, "BANLINE", "Hit ban line. Stopping. Back out.", movemag);   // note hit ban line
                llSetPos(gLastSafePos);             // move to safe position
                llSleep(0.5);                       // wait for move
                llSetStatus(STATUS_PHYSICS, TRUE);  // turn physics back on
            } else {
                gLastSafePos = pos;
            }
        }
    }

    //  Stop temporarily during region crossing until rider catches up.
    if (crossStopped)                               // if stopped at region crossing
    {   integer allseated = TRUE;
        integer pilotUnseat = FALSE;                // Is pilot unseated ?
        key passUnseat = NULL_KEY;                  // Key of mis-seated passenger
        integer i;
        integer sittercount = llGetListLength(gSitters); // number of sitters
        for (i = 0; i < sittercount; i++)
        {   if (ifnotseated(llList2Key(gSitters,i), llList2Float(gSitterDistances,i), gLogMsgLevel <= LOG_DEBUG))
            {
                allseated = FALSE;
                if (llList2Key(gSitters, i) == driverKey) {
                    pilotUnseat = TRUE;             // Mark pilot not seated
                } else {
                    passUnseat = llList2Key(gSitters, i);
                }
            }
        }
        if (allseated)                              // if all avatars are back in place
        {   llSetStatus(STATUS_PHYSICS, TRUE);      // physics back on
            vector CROSS_DOWN_VEL = <0,0,-1.0>;     // extra down velocity ***TEMP***
            llSetVelocity(crossVel + CROSS_DOWN_VEL, FALSE);         // use velocity from before
            ////llOwnerSay("End crossing. Z vel: " + (string)crossVel.z); // ***TEMP***
            crossVel = <0,0,0>;                     // consume velocity - do not use twice
            llSetAngularVelocity(crossAngularVelocity, FALSE);  // and angular velocity
            crossStopped = FALSE;                   // no longer stopped
            float crosstime = llGetTime() - crossStartTime;
            logrx(LOG_NOTE, "CROSSEND", "Region crossing complete in ",crosstime);
            ////llOwnerSay("Velocity in: " + (string)llVecMag(crossVel) + "  out: " + (string)llVecMag(llGetVel()));
        } else {
            if ((llGetTime() - crossStartTime) > MAX_CROSSING_TIME)  // taking too long?
            {
                /*  After MAX_CROSSING_TIME we are still missing a sitter
                    from the pre-crossing complement.  If this is the pilot,
                    we're probably in an unrecoverable situation.  But if we've
                    lost a passenger, that's too bad, so sad, but the pilot and
                    vehicle can continue.  Let's hope the passenger has bus fare
                    back home.  */

                if (!pilotUnseat) {
                    logrx(LOG_FAULT, "LOSTPASS", "Lost passenger " + (string) passUnseat + " after max crossing time.",
                        llGetTime() - crossStartTime);
                        llSetStatus(STATUS_PHYSICS, TRUE);      // physics back on
                        llSetVelocity(crossVel, FALSE);         // use velocity from before
                        crossVel = ZERO_VECTOR;                 // consume velocity - do not use twice
                        llSetAngularVelocity(crossAngularVelocity, FALSE);  // and angular velocity
                        crossStopped = FALSE;                   // no longer stopped
                        float crosstime = llGetTime() - crossStartTime;
                        logrx(LOG_NOTE, "CROSSEND", "Region crossing complete in ", crosstime);
if (passUnseat != NULL_KEY) {
    llUnSit(passUnseat);            // Kick off hopelessly un-seated passengers
llOwnerSay("Kicking off un-seated passenger: " + (string) passUnseat);
}
                        integer sitters = updatesitters();      // Update sitters now that passenger is gone
llOwnerSay("Sitters after losing passenger: " + (string) sitters);
                        return TICK_NORMAL;
                }

                if (!crossFault)                    // once only
                {   logrx(LOG_FAULT, "CROSSFAIL", "Crossing is taking too long. Probably stuck. Try teleporting out.", llGetTime()-crossStartTime);
                    crossFault = TRUE;
                    return(TICK_FAULT);
                }
            }
            if (llGetUnixTime() - gLastMsgTime > 2.0)
            {   logrx(LOG_WARN, "CROSSSLOW","Waiting for avatar(s) to cross regions.",0.0);            // send at least one message every 60 seconds
            }
            return(TICK_CROSSSTOPPED);              // still cross-stopped
        }
    }
//    if (llGetUnixTime() - gLastMsgTime > MAX_SECS_BETWEEN_MSGS)
//    {   logrx(LOG_DEBUG, "TICK","", gDistanceTraveled/1000.0); }          // send at least one message every 60 seconds
    return(TICK_NORMAL);                            // not in trouble
}

//  End Animats RegionRX code

    //  Event handler

    default {
        on_rez(integer num) {
            llResetScript();
        }

        state_entry() {
        }

        /*  The link_message() event receives commands from the main
            vehicle script and passes them on to the RegionRX functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//llOwnerSay("Link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_RX_INIT (30): Initialise vehicle

            if (num == LM_RX_INIT) {
                DRIVER_SEAT_LINK = (integer) str;   // Save link number of driver's seat
//llOwnerSay("Driver link: " + (string) DRIVER_SEAT_LINK + " s " + str);
                initregionrx(LOG_DEBUG);             // Initialise RegionRX

            //  LM_RX_RESET (31): Reset script

            } else if (num == LM_RX_RESET) {
                llResetScript();

            //  LM_RX_STAT (32): Print status

            } else if (num == LM_RX_STAT) {
                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                llRegionSayTo(id, PUBLIC_CHANNEL,
                    "Region crossing script memory.  Free: " + (string) mFree +
                    "  Used: " + (string) mUsed + " (" +
                    (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)");

            //  LM_RX_CHANGED (34): Region or link changed

            } else if (num == LM_RX_CHANGED) {
                list arg = llJson2List(str);
//llOwnerSay("RX changed: " + llList2CSV(arg));
                //  args:  change_flags, nseats, driver_link, passenger_link,...
                DRIVER_SEAT_LINK  = llList2Integer(arg, 2);
                //  We don't worry about passenger link numbers at this level
                handlechanged( llList2Integer(arg, 0));

            //  LM_VM_TRACE (113): Set trace level

            } else if (num == LM_VM_TRACE) {
                gLogMsgLevel = LOG_ERR;
                if (llList2Integer(llJson2List(str), 0) > 0) {
                    gLogMsgLevel = LOG_DEBUG;
                }

            }
        }

        timer() {
            if (llAvatarOnLinkSitTarget(DRIVER_SEAT_LINK) != NULL_KEY) {
                handletimer();
            }
//else { llOwnerSay("Bogus timer tick after pilot stands."); }
        }

    }
