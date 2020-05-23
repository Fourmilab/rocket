    /*

               Fourmilab Rocket Pilotage

                    by John Walker

    */

    //  Control processing

    integer stable = FALSE;     // Are controls stable after sit transient ?
    integer stableTicks = 2;    // Timer ticks before we're stable
    integer stableCount = 0;    // Counter to await stability

    integer showPanel = TRUE;   // Show control panel (floating text)
    integer restrictAccess = 2; // Access restriction: 0 none, 1 group, 2 owner

    string nameOrig;            // Original name of root prim
    float volume = 1;           // Sound volume
    vector smokeColour = <0.75, 0.75, 0.75>;    // Smoke trail colour
    float smokeAlpha = 1;       // Smoke trail transparency (1 = solid)
    integer fired = FALSE;      // Fire keystrokes pressed

    float X_THRUST = 20;        // Thrust along X axis
    float Z_THRUST = 15;        // Thrust along Y axis

    float xMotor;               // Current thrust setting for X motor
    float zMotor;               // Current thrust setting for Z motor

    //  Sit / unsit

    integer starting = FALSE;   // Are we starting the engine ?
    integer eStopped = FALSE;   // Is engine artificially stopped
    float tStarting;            // Time to switch from start to engine loop
    vector pPos;                // Relative position of pilot
    rotation pRot;              // Relative rotation of pilot
    integer pilotPerms;         // Permissions requested from pilot avatar
    integer sitLinkPilot = 0;   // Link of seated pilot
    integer sitLinkPassenger = 0;   // Link of seated passenger
    integer regionChangeControls = FALSE;  // Restoring controls after region change ?

    //  Autopilot

    integer autoEngaged = FALSE; // Is autopilot engaged ?
    float autoAltTolerance = 3; // Autopilot altitude tolerance, metres
    float autoRangeTolerance = 3; // Autopilot range tolerance, metres
    float autoCruiseAlt = 120;  // Autopilot cruise altitude, above terrain
    float autoDeadBand = 0.1;   // Heading dead band, radians
    float autoDz;               // Autopilot altitude current error
    float autoTurnAuth = 1;     // Autopilot turn authority
    float autoThrustAuth = 1;   // Autopilot thrust authority
    integer CONTROL_AUTOPILOT = 0x800;  // Command from autopilot
    integer CONTROL_COLLISION = 0x1000; // Command due to collision recovery
    float autoRange = 0;        // Current range to destination
    integer autoLandEnable = TRUE; // Enable automatic landing ?
    integer autoLand = FALSE;   // Automatic landing in progress
    integer autoTurn = FALSE;   // Turn in progress
    integer autoRangeInterval = 1; // Update navigation legend this number of seconds
    float autoRangeTime = 0;    // Next range reporting time
    integer autoSuspendTime = 5; // Autopilot suspend time after manual command entered
    float autoSuspendExp = 0;   // Time autopilot suspend expires
    string autoCollide = "";    // Last object with which we collided
    integer autoCollideCount = 0; // Number of collisions
    float autoSAMinterval = 1;  // Probe SAM threats every this seconds
    float autoSAMtime = 0;      // Next SAM threat probe time
    integer updateDistInterval = 1; // Update distance travelled this seconds
    float updateDistTime = 0;   // Time of next distance travelled update
    integer autoDivertActive = FALSE;   // Is a SAM evasion divert active ?
    float autoDivertRange;      // SAM range to threat site
    vector autoDivertG;         // SAM evasion waypoint (grid)
    vector autoDivertR;         // SAM evasion waypoint (region)
    string autoDivertSite;      // SAM threat site label
    integer autoThrottleDown = FALSE;   // Throttled down at region crossing ?
    integer autoCornerDivert = FALSE;   //  Diverting to avoid region corner ?
    vector cornerDivertPos;     // Corner divert destination within region
    integer stuckCount = 0;     // Stuck counter
    float stuckStart = 0;       // Stuck starting time
    float velDestSmooth = -9999;    // Smoothed velocity toward destination
    float stalledTime = 5;      // Time before we issue stalled warning
    integer stalledWarn = FALSE;    // Is a stalled warning active ?

    string destRegion = "";     // Region name of destination
    vector destGrid;            // Grid co-ordinates of destination
    vector destRegc;            // Destination co-ordinates within region

    //  Terrain following

    float tfTerrain = 0;        // Current terrain estimate
    float lastObjectCollision = 0;      // Time of last object collision
    key lastObjectCollisionKey;         // UUID of last object we hit
    float lastTerrainCollision = 0;     // Time of last terrain collision
    integer tfObstacles = TRUE; // Fly up to avoid obstacles in path ?

    //  Script processing

    integer scriptActive = FALSE;   // Are we reading from a script ?
    integer scriptSuspend = FALSE;  // Suspend script execution for asynchronous event

    key owner;                  // UUID of owner
    key agent;                  // UUID of agent sitting on control seat
    key ivagent;                // UUID of invalid agent sitting on control seat
    key passenger;              // UUID of agent on passenger seat
    key exPassenger;            // UUID of passenger who just departed
    key whoDat = NULL_KEY;      // Avatar who sent command
    integer REGION_SIZE = 256;  // Size of region in metres
    integer trace;              // Generate trace output ?

    //  Statistics

    integer statRegionX = 0;    // Region crossings
    float statDistance = 0;     // Distance travelled
    vector statLpos;            // Last position for odometer
    integer statLand = 0;       // Auto-landings performed
    integer statCollO = 0;      // Collisions with objects
    integer statCollT = 0;      // Collisions with terrain
    integer statSAM = 0;        // SAM diverts
    integer statCorner = 0;     // Corner diverts
    integer statDests = 0;      // Destinations arrived at
    integer statDrop = 0;       // Anvils dropped
    float statMETstart = 0;     // Mission start time
    float statMETlast = 0;      // Mission last time

    //  Target interface

    integer hitChannel = -982449715;    // Target hit announcement channel
    integer targetChannel = 2959;   // Target command channel
    integer hitH;               // Target listener handle
    integer T_nhits;            // Total hits
    integer T_nscore;           // Total score for all hits


    //  Link indices within the object

    integer lSaddle;            // Nosecone
    integer lTailpipe;          // Tail pipe
    integer lPilot;             // Link used as pilot seat
    integer lPassenger;         // Link used as passenger seat
/* IF ROCKET  */
    integer lNozzle;            // Exhaust nozzle

    integer lFin1;              // Tail fin 1
    integer lFin2;              // Tail fin 2
    integer lFin3;              // Tail fin 3
    integer lFin4;              // Tail fin 4
/* END ROCKET */

    /*  The following sets where the pilot (first to be
        seated) and passenger (second to board) sit and
        the camera angle from which they observe when in
        flight.  */

    //  Pilot sits on pilot seat (first seat link)
/* IF ROCKET  */
    vector dSIT_POS = <-0.95, 0, 1.5>;  // Pilot sit position on vehicle
/* END ROCKET */
/* IF UFO 
    vector dSIT_POS = <-0.95, 0, 0.35>;  // Pilot sit position on vehicle
/* END UFO */
    vector dSIT_ROTATION = <0, -90, 0>; // Rotation of pilot to sit position
    //  In these offsets:
    //      X   Distance above (-) / below (+) sit position
    //      Z   Distance behind (+) / ahead (-) sit position
/* IF ROCKET  */
    vector dCAM_OFFSET = <-1.5, 0, -1.5>;   // Offset of camera lens from pilot sit position
    vector dCAM_ANG = <0, 0, 8>;        // Camera look-at point relative to pilot CAM_OFFSET
/* END ROCKET */
/* IF UFO 
    vector dCAM_OFFSET = <-1.5, 0, -1.5>;   // Offset of camera lens from pilot sit position
    vector dCAM_ANG = <0, 0, 8>;        // Camera look-at point relative to pilot CAM_OFFSET
/* END UFO */

    //  Passenger sits on passenger seat (second seat link)
/* IF ROCKET  */
    vector pSIT_POS = <0.8, 0, -2.5>;   // Passenger sit position on vehicle
    vector pSIT_ROTATION = <0, 90, 180>;    // Rotation of passenger to sit position
/* END ROCKET */
/* IF UFO 
    vector pSIT_POS = <-0.80, 0, -0.1>;    // Passenger sit position on vehicle
    vector pSIT_ROTATION = <0, -90, 0>; // Rotation of passenger to sit position
/* END UFO */
    //  In these offsets:
    //      X   Distance above (-) / below (+) sit position
    //      Z   Distance behind (+) / ahead (-) set position
/* IF ROCKET  */
    vector pCAM_OFFSET = <-2, 0, -3>;   // Offset of camera lens from passenger sit position
    vector pCAM_ANG = <0, 0, 1>;        // Camera look-at point relative to passenger CAM_OFFSET
/* END ROCKET */
/* IF UFO 
    vector pCAM_OFFSET = <-2, 0, -3>;   // Offset of camera lens from passenger sit position
    vector pCAM_ANG = <0, 0, 1>;        // Camera look-at point relative to passenger CAM_OFFSET
/* END UFO */

    //  Vehicle Auxiliary Messages
    integer LM_VX_INIT = 10;        // Initialise
    integer LM_VX_PISTAT = 13;      // Print Pilotage status
    integer LM_VX_PIPANEL = 14;     // Display pilot's control panel
    integer LM_VX_HEARTBEAT = 15;   // Request heartbeat

    //  Pilotage messages

    integer LM_PI_INIT = 20;        // Initialise
    integer LM_PI_RESET = 21;       // Reset script
    integer LM_PI_STAT = 22;        // Print status
    integer LM_PI_DEST = 23;        // Set destination
    integer LM_PI_SETTINGS = 24;    // Update pilotage settings
    integer LM_PI_ENGAGE = 25;      // Engage/disengage autopilot
    integer LM_PI_FIRE = 26;        // Fire weapon / handle impact
    integer LM_PI_PILOT = 27;       // Pilot sit / unsit
    integer LM_PI_TARGCLR = 28;     // Clear target statistics
    integer LM_PI_MENDCAM = 29;     // Mend camera tracking

    //  Region Crossing messages
    integer LM_RX_INIT = 30;        // Initialise vehicle
    integer LM_RX_CHANGED = 34;     // Region or link changed

    //  Sounds Messages
    integer LM_SO_PLAY = 43;        // Play sound
    integer LM_SO_PRELOAD = 44;     // Preload sound

    //  Script Processor messages
    integer LM_SP_INIT = 50;        // Initialise

    //  Passengers messages
//  integer LM_PA_INIT = 60;        // Initialise
//  integer LM_PA_RESET = 61;       // Reset script
//  integer LM_PA_STAT = 62;        // Print status
    integer LM_PA_SIT = 63;         // Passenger sits on vehicle
    integer LM_PA_STAND = 64;       // Passenger stands, leaving vehicle

    //  Terrain Following messages
    integer LM_TF_ACTIVATE = 73;    // Turn terrain following on or off
    integer LM_TF_TERRAIN = 74;     // Report terrain height to client

    //  SAM Sites messages
    integer LM_SA_COMPLETE = 95;    // Chat command processing complete
    integer LM_SA_PROBE = 96;       // Probe for threats
    integer LM_SA_DIVERT = 97;      // Diversion temporary waypoint advisory

    //  Trace messages
    integer LM_TR_SETTINGS = 120;       // Broadcast trace settings
    //  Trace module selectors
    integer LM_TR_S_PILOT = 2;          // Pilotage

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

    /*  ttawk  --  Send a message with tawk(), but only if trace
                   is nonzero.  This should only be used for simple
                   messages generated infrequently.  For complex,
                   high-volume messages you should use:
                       if (trace) { tawk(whatever); }
                   because that will not generate the message or call a
                   function when trace is not set.  */

    ttawk(string msg) {
        if (trace) {
            tawk(msg);
        }
    }

    //  checkAccess  --  Check if user has permission to send commands

    integer checkAccess(key id) {
        return (restrictAccess == 0) ||
               ((restrictAccess == 1) && llSameGroup(id)) ||
               (id == llGetOwner());
    }

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

    /*  regCorner  --  Return the angle between vector dir and the
                       closest of the four corners of the region.
                       The result will be an angle between 0 and
                       (PI / 4): the unsigned angle between dir and
                       the closest corner of the region.  */

    float regCorner(vector dir) {
        dir.z = 0;                  // We only care about horizontal bearing
        dir = llVecNorm(dir);       // Normalise if not already done
        return llAcos(max(llFabs(dir * llVecNorm(<1, 1, 0>)),
                          llFabs(dir * llVecNorm(<1, -1, 0>))));
    }

    /*  quadrant  --  Determine which corner of the region is closer
                      based on the signs of the X and Y components of
                      a direction vector dir.  Returns a list in which
                      the first item is an integer indicating the quadrant:
                            0   Indeterminate
                            1   Northeast
                            2   Southeast
                            3   Southwest
                            4   Northwest
                        and the second item is a vector giving the co-ordinates
                        of the closest region corner.  */

    list quads = [ "?", "NE", "SE", "SW", "NW" ];

    list quadrant(vector dir) {
        integer q = 0;
        vector corner = ZERO_VECTOR;
        if (dir.y > 0) {
            if (dir.x > 0) {
                q = 1;                  // NE
                corner = < REGION_SIZE, REGION_SIZE, 0 >;
            } else if (dir.x < 0) {
                q = 4;                  // NW
                corner = < 0, REGION_SIZE, 0 >;
            }
        } else if (dir.y < 0) {
            if (dir.x > 0) {
                q = 2;                  // SE
                corner = < REGION_SIZE, 0, 0 >;
            } else if (dir.x < 0) {
                q = 3;                  // SW
                corner = < 0, 0, 0 >;
            }
        }
        return [ q, corner ];
    }

    /*  scriptResume  --  Resume script execution when asynchronous
                          command completes.  */

    scriptResume() {
//        ttawk("scriptResume(): scriptActive " + (string) scriptActive + "  scriptSuspend " + (string) scriptSuspend);
        if (scriptActive) {
            if (scriptSuspend) {
                scriptSuspend = FALSE;
                llMessageLinked(LINK_THIS, LM_SA_COMPLETE, "1", whoDat);
                ttawk("Script resumed.");
            }
        }
    }

    //  setSitPositions  --  Define sit positions and camera

    setSitPositions() {

        //  Revoke any legacy linkset-wide sit target and camera overrides
        llSitTarget(ZERO_VECTOR, ZERO_ROTATION);
        llSetCameraAtOffset(ZERO_VECTOR);
        llSetCameraEyeOffset(ZERO_VECTOR);

        /*  Earlier alarums and diversions may have set sit targets on
            prims which are now irrelevant.  Clear them to avoid
            endless confusion if they persist.  */

        integer n = llGetNumberOfPrims() + 1;
        integer i;
        for (i = 1; i < n; i++) {
            llLinkSitTarget(i, ZERO_VECTOR, ZERO_ROTATION);
        }

        //  Define sit positions and camera for pilot and passenger
        lPilot = lTailpipe;
/* IF ROCKET  */
        lPassenger = lSaddle;
/* END ROCKET */
        llLinkSitTarget(lPilot, dSIT_POS,
            llEuler2Rot(dSIT_ROTATION * DEG_TO_RAD));
        llSetLinkCamera(lPilot, dCAM_OFFSET, dCAM_ANG);
        llLinkSitTarget(lPassenger, pSIT_POS, llEuler2Rot(pSIT_ROTATION * DEG_TO_RAD));
        llSetLinkCamera(lPassenger, pCAM_OFFSET, pCAM_ANG);
    }

/* IF ROCKET  */

    //  Control smoke emission from nozzle

    smoke(integer on) {
        if (on) {
            if (smokeAlpha > 0) {
                llLinkParticleSystem(lTailpipe,
                    [ PSYS_PART_FLAGS, PSYS_PART_EMISSIVE_MASK,
                      PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_DROP,
                      PSYS_PART_START_SCALE, <0.3, 0.3, 0.3>,
                      PSYS_PART_START_COLOR, smokeColour,
                      PSYS_PART_START_ALPHA, smokeAlpha,
                      PSYS_PART_END_ALPHA, 0.0,
                      PSYS_PART_MAX_AGE, 10.0,
                      PSYS_SRC_BURST_RATE, 0.0 ]);
                    }
        } else {
            llLinkParticleSystem(lTailpipe, []);
        }
    }
/* END ROCKET */

    //  fire  --  Create a projectile and launch toward the target

    fire() {
        vector vel;                         //  Velocity of projectile
        vector pos;                         //  Position of projectile
        rotation rot;                       //  Rotation of projectile
        string bombName = "Fourmilab Anvil: Rocket Bomb";       // Name of bomb in inventory
        rotation bombRot = llEuler2Rot(<PI, -PI_BY_TWO, 0>);    // Rotation of bomb to upright
        integer LIFETIME = 60;          //  Life of projectiles in seconds

         //  Fire the projectile

        /*  Set the initial position and velocity so the bomb
            inherits the velocity of the vehicle.  There is a
            quite a bit of "ad hack" tweaking in here based upon
            experiments to keep the bomb from recontacting the
            vehicle after release.  We release far enough down
            in Z to miss the nose cone and tail fins in high
            speed separation, and if we're descending, we give it
            an extra downward impulse to keep from running into
            it before gravity accelerates it sufficiently to
            get away from us.  */

        vel = llGetVel();   // Velocity in global co-ordinates
        pos = llGetPos();               //  Get position of avatar to create projectile
/* IF ROCKET  */
        pos.z -= 0.8;                   //  Set launch point (too high and it will blow up in bomb bay)
/* END ROCKET */
/* IF UFO 
        pos.z -= 1.2;                   //  Set launch point (too high and it will blow up in bomb bay)
/* END UFO */
        if (vel.z < 0) {
            vel.z *= 5;
        }

        rot = llGetRot();               //  Get current avatar mouselook direction
        rot = bombRot * rot;            // Rotate so anvil aligns with rocket body

        /*  Create the actual projectile from object
            inventory, and set its position, velocity,
            and rotation.  Pass a parameter to it to
            tell it how long to live.  */
        llRezObject(bombName, pos, vel, rot, LIFETIME);
        statDrop++;
    }

    //  autoDisengage  --  Disengage autopilot

    autoDisengage() {
        if (autoEngaged) {
            autoLand = autoEngaged = autoCornerDivert = FALSE;
            autoSuspendExp = 0;
            velDestSmooth = -9999;
            llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION, ZERO_VECTOR);
            llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION, ZERO_VECTOR);
            llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_TEXT, "", < 0, 0, 0 >, 0 ]);
            llMessageLinked(LINK_THIS, LM_TF_ACTIVATE,
                llList2Json(JSON_ARRAY, [ 0, 1.0 ]) , NULL_KEY);
            tawk("Autopilot disengaged.");
            scriptResume();
        }
    }

    //  processControl  --  Process a control input

    processControl(integer level, integer edge) {
        vector angular_motor;

        /*  For some screwball reason, shortly after we take controls, we'll
            get a few random control inputs which weren't made by the user.
            We use the stable timer to ignore them until things settle down.  */

        if (!stable) {
            return;
        }

        //  Forward and backward motion keys together or left mouse to fire

        if (((edge & CONTROL_ML_LBUTTON) == CONTROL_ML_LBUTTON) &&
            ((level & CONTROL_ML_LBUTTON) == CONTROL_ML_LBUTTON)) {
            //  When left mouse button is pressed, fire missile
            fire();
        }

        if (fired) {
            if (((level & CONTROL_FWD) == 0) && ((level & CONTROL_BACK) == 0)) {
                fired = FALSE;
            } else {
                return;
            }
        }

        if ((level & CONTROL_FWD) && (level & CONTROL_BACK)) {
            fired = TRUE;
            fire();
            return;
        }

        /*  If the autopilot is engaged and this is a command from
            the user, suspend the autopilot for autoSuspendTime
            since the last user control input.  */

        if (autoEngaged && (!(level & CONTROL_AUTOPILOT)) && (!(level & CONTROL_BACK))) {
            if (autoSuspendExp == 0) {
                tawk("Autopilot suspended.");
            }
            llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_TEXT, "", < 0, 0, 0 >, 0 ]);
            autoSuspendExp = llGetTime() + autoSuspendTime;
        }

        //  Forward and backward motion keys

        if ((level & CONTROL_FWD) || (level & CONTROL_BACK)) {
            if (edge & CONTROL_FWD) xMotor = X_THRUST;
            if (edge & CONTROL_BACK) xMotor = -X_THRUST;
            if ((level & CONTROL_AUTOPILOT) && autoEngaged) {
                xMotor *= autoThrustAuth;
            }
        } else {
            xMotor = 0;
         }

        //  Upward and downward motion keys

        if ((level & CONTROL_UP) || (level & CONTROL_DOWN)) {
            if (level & CONTROL_UP) {
                zMotor = Z_THRUST;
            }
            if (level & CONTROL_DOWN) {
                zMotor = -Z_THRUST;
            }
            //  Get very serious when recovering from collision
            if (level & CONTROL_COLLISION) {
                zMotor *= 10;           // TOGA, TOGA, TOGA!
            //  Apply proportional control if autopilot engaged
            } else if (level & CONTROL_AUTOPILOT) {
                if (autoEngaged) {
                    float zerror = llFabs(autoDz) / (autoAltTolerance * Z_THRUST * 3);
                    if (zerror < 1) {
                        zMotor *= zerror;
                    }
                }
            }
        } else {
            zMotor = 0;
        }

        llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION,
            <xMotor, 0, zMotor>);

/* IF ROCKET  */
        //  Deflect horizontal fins based on zMotor setting

        vector udrot = llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(lFin2,
                    [ PRIM_ROT_LOCAL ]), 0));
        udrot.z = (90 + zMotor) * DEG_TO_RAD;
        llSetLinkPrimitiveParamsFast(lFin2,
                [ PRIM_ROT_LOCAL, llEuler2Rot(udrot) ]);
        udrot = llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(lFin4,
                    [ PRIM_ROT_LOCAL ]), 0));
        udrot.z = (270 - zMotor) * DEG_TO_RAD;
        llSetLinkPrimitiveParamsFast(lFin4,
                [ PRIM_ROT_LOCAL, llEuler2Rot(udrot) ]);
/* END ROCKET */

        //  Left and right turn keys

        if (level & CONTROL_RIGHT) {
            angular_motor.x = TWO_PI;
            angular_motor.y /= 8;
        }

        if (level & CONTROL_LEFT) {
            angular_motor.x = -TWO_PI;
            angular_motor.y /= 8;
        }

        if (level & CONTROL_ROT_RIGHT) {
            angular_motor.x = TWO_PI;
            angular_motor.y /= 8;
        }

        if (level & CONTROL_ROT_LEFT) {
            angular_motor.x = -TWO_PI;
            angular_motor.y /= 8;
        }

        //  Apply proportional control if autopilot engaged
        if (level & CONTROL_AUTOPILOT) {
             if (autoEngaged) {
                 angular_motor *= autoTurnAuth;
            }
        }

        llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION,
            angular_motor);

/* IF ROCKET  */
        //  Deflect vertical fins based on angular motor setting

        udrot = llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(lFin1,
                    [ PRIM_ROT_LOCAL ]), 0));
        udrot.z = -(angular_motor.x / 20);
        llSetLinkPrimitiveParamsFast(lFin1,
            [ PRIM_ROT_LOCAL, llEuler2Rot(udrot) ]);
        udrot = llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(lFin3,
                    [ PRIM_ROT_LOCAL ]), 0));
        udrot.z = PI + (angular_motor.x / 20);
        llSetLinkPrimitiveParamsFast(lFin3,
            [ PRIM_ROT_LOCAL, llEuler2Rot(udrot) ]);

        //  Deflect the nozzle based upon Z linear and angular motor

        udrot = llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(lNozzle,
                    [ PRIM_ROT_LOCAL ]), 0));
        udrot.y = -zMotor * DEG_TO_RAD;
        udrot.x = -(angular_motor.x / 20);
        llSetLinkPrimitiveParamsFast(lNozzle,
            [ PRIM_ROT_LOCAL, llEuler2Rot(udrot) ]);

        //  Make smoke while we're moving
        smoke((xMotor != 0) || (zMotor != 0) || (angular_motor.x != 0));
/* END ROCKET */

        //  Adjust the vehicle tilt proportional to the Z motor thrust
        llSetVehicleRotationParam(VEHICLE_REFERENCE_FRAME,
            llEuler2Rot(< 0, (-(PI / 2)) + (zMotor * DEG_TO_RAD), 0 >));

        //  Disengage autopilot and terminate any script if the Back key is pressed
        if (autoEngaged && (!(level & CONTROL_AUTOPILOT)) &&
            (level & CONTROL_BACK) && (autoSuspendExp < llGetTime())) {
            autoDisengage();
            if (scriptActive) {
                scriptActive = scriptSuspend = FALSE;
                llMessageLinked(LINK_THIS, LM_SP_INIT, "", whoDat); // Reset Script Processor
            }
        }
    }

    //  Event processor

    default {
        state_entry() {
            owner = llGetOwner();
            agent = ivagent = passenger = NULL_KEY;

            pilotPerms =  PERMISSION_TAKE_CONTROLS |    // Permissions we request
                          PERMISSION_CONTROL_CAMERA |
PERMISSION_TRACK_CAMERA; // |
//                          PERMISSION_TRIGGER_ANIMATION;

            //  Save original description of root prim
            nameOrig = llList2String(llGetLinkPrimitiveParams(LINK_ROOT, [ PRIM_NAME ]), 0);
            integer unx = llSubStringIndex(nameOrig, ": ");
            if (unx > 0) {
                nameOrig = llGetSubString(nameOrig, 0, unx - 1);
            }

            //  Find and save link numbers for child prims
/* IF ROCKET  */
            lSaddle = findLinkNumber("Nosecone");
            lNozzle = findLinkNumber("Nozzle");
            lTailpipe = findLinkNumber("Tailpipe");
            lFin1 = findLinkNumber("Tail Fin 1");
            lFin2 = findLinkNumber("Tail Fin 2");
            lFin3 = findLinkNumber("Tail Fin 3");
            lFin4 = findLinkNumber("Tail Fin 4");
/* END ROCKET */
/* IF UFO 
            lSaddle = findLinkNumber("Saucer bottom");
            lTailpipe = findLinkNumber("Fourmilab Flying Saucer");
            lPassenger = findLinkNumber("Passenger seat");
llLinkSitTarget(findLinkNumber("Dome"), ZERO_VECTOR, ZERO_ROTATION); // Remove bogus sit target
/* END UFO */
            setSitPositions();
        }

        //  When we're instantiated, reset script

        on_rez(integer num) {
            llResetScript();
        }

        //  When granted permission, take control keys

        run_time_permissions(integer perm) {
            ttawk("Requesting pilot permissions: " + (string) perm);
            if (perm & PERMISSION_TAKE_CONTROLS) {
                llTakeControls(CONTROL_UP |
                               CONTROL_DOWN |
                               CONTROL_FWD |
                               CONTROL_BACK |
                               CONTROL_RIGHT |
                               CONTROL_LEFT |
                               CONTROL_ROT_RIGHT |
                               CONTROL_ROT_LEFT |
                               CONTROL_ML_LBUTTON, TRUE, FALSE);
if (regionChangeControls) {
    regionChangeControls = FALSE;
    return;
}
            }

            //  Set pilot's camera position

            if (perm & PERMISSION_CONTROL_CAMERA) {
                llClearCameraParams();              // Restore all defaults
                llSetCameraParams([
                    CAMERA_ACTIVE, 1,               // We control the camera
                    CAMERA_BEHINDNESS_ANGLE, 0.0,   // How closely we track, degrees
                    CAMERA_BEHINDNESS_LAG, 0.0,     // Response time tracking target, seconds
/* IF ROCKET  */
                    CAMERA_DISTANCE, 5.5,           // Distance to target, metres
/* END ROCKET */
/* IF UFO 
                    CAMERA_DISTANCE, 9.5,           // Distance to target, metres
/* END UFO */
                    CAMERA_FOCUS_LAG, 0.0,          // Target tracking time, seconds
/* IF ROCKET  */
                    CAMERA_FOCUS_OFFSET, <2, 0, 0>, // Camera focus position relative to target
/* END ROCKET */
/* IF UFO 
                    CAMERA_FOCUS_OFFSET, <0, 0, 0>, // Camera focus position relative to target
/* END UFO */
                    CAMERA_FOCUS_THRESHOLD, 0.0,    // Region to ignore target motion, metres
/* IF ROCKET  */
                    CAMERA_PITCH, 5.0,              // Camera pitch relative to target
/* END ROCKET */
/* IF UFO 
                    CAMERA_PITCH, 25.0,              // Camera pitch relative to target
/* END UFO */
                    CAMERA_POSITION_LAG, 0.0,       // Camera position adjust lag, seconds
                    CAMERA_POSITION_THRESHOLD, 0.0  // Ignore camera position errors, metres
                ]);
            }
        }

        /*  The control event receives messages when one of the flight
            control keys we've captured is pressed.  It adjusts the
            thrust on the X and Z axis linear motors and the angular
            motor for turns.  */

        control(key id, integer level, integer edge) {
            processControl(level, edge);
        }

        /*  The changed event handler detects when an avatar
            sits on the vehicle or stands up and departs.
            Note: if you need to link or unlink prims from the
            composite object, you *MUST* add code to this event
            to just return without doing anything.  Otherwise
            the link change will be interpreted as a sit/stand
            event and cause all kinds of mayhem.  */

        changed(integer change) {
            if (change & CHANGED_REGION) {
                statRegionX++;                  // Increment regions crossed
                autoCornerDivert = FALSE;       // Mark corner divert done if active
                stuckCount = 0;                 // Mark not stuck
//  EXPERIMENT: TRY RESTORING CONTROL ON REGION CHANGE
regionChangeControls = TRUE;
llReleaseControls();
llRequestPermissions(agent, pilotPerms);
            }

            if (change & CHANGED_LINK) {
                key agentC = llAvatarOnLinkSitTarget(lPilot);           // Avatar on pilot seat
                key passengerC = llAvatarOnLinkSitTarget(lPassenger);   // Avatar on passenger seat

//llOwnerSay("Pilotage change:  agentC " + (string) agentC + "  passengerC " + (string) passengerC +
//    "  agent " + (string) agent + "  passenger " + (string) passenger +
//    "  lPilot " + (string) lPilot + "  lPassenger " + (string) lPassenger);

                if ((agentC == NULL_KEY) && (agent != NULL_KEY)) {
//llOwnerSay("Pilot stands.");
                    //  Pilot has stood up, departing
                    agent = agentC;
                    vector np = llGetRegionCorner() + llGetPos();
                    statDistance += llVecDist(statLpos, np); // Final odometer update
                    statLpos = np;

                    sitLinkPilot = 0;
                    llSetStatus(STATUS_PHYSICS, FALSE);
                    llSetLinkPrimitiveParamsFast(LINK_ROOT, [ PRIM_NAME, nameOrig ]);
                    llReleaseControls();
                    llMessageLinked(LINK_THIS, LM_PI_PILOT, "", agent);
                    statMETlast = llGetTime();          // Save end of mission time
                    exPassenger = NULL_KEY;             // Clear exPassenger

                    //  Cancel our event timer
                    llSetTimerEvent(0);

                    //  Remove target hit listener
                    llListenRemove(hitH);

                    //  If enabled, hide control panel
                    if (showPanel) {
                        llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_TEXT, "", ZERO_VECTOR, 0 ]);
                    }

                    //  Disengage autopilot
                    autoDisengage();

                    //  If script is active, terminate it
                    if (scriptActive) {
                        scriptActive = scriptSuspend = FALSE;
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", whoDat); // Reset Script Processor
                    }

                    if (!eStopped) {                // Skip if engine sound already stopped
                        starting = FALSE;           // Just in case we're still starting
                        if (volume > 0) {
/* IF ROCKET  */
                            llPlaySound("Engine stop", volume);
/* END ROCKET */
/* IF UFO 
                            llStopSound();
/* END UFO */
                        }
                    }
                    eStopped = FALSE;

/* IF ROCKET  */
                    //  Return nozzle to engine off
                    llSetLinkPrimitiveParamsFast(lNozzle,
                        [ PRIM_COLOR, 2, <0.15, 0.15, 0.15>, 1 ]);
                    llSetLinkPrimitiveParamsFast(lNozzle, [ PRIM_GLOW, 2, 0 ]);

                    //  Make sure smoke is off
                    smoke(FALSE);
/* END ROCKET */
                } else if ((agentC == NULL_KEY) && (ivagent != NULL_KEY)) {
                    ivagent = NULL_KEY;
                    //  Unauthorised pilot leaves vehicle
//llOwnerSay("Invalid pilot stands.");
                    return;
                } else if ((passenger != NULL_KEY) && (passengerC == NULL_KEY)) {
                    //  Passenger has departed
//llOwnerSay("Passenger stands.");
                    exPassenger = passenger;        // Remember departing passenger
                    passenger = NULL_KEY;
                    sitLinkPassenger = 0;
                    if (ivagent != NULL_KEY) {
                        return;                     // Just a simple sit if pilot invalid
                    }
                    llMessageLinked(LINK_THIS, LM_PA_STAND,
                        llList2Json(JSON_ARRAY, [
                            lPassenger,             // Link on which passenger was seated
                            1                       // Passenger number: 1 -- n
                        ]), agent);                 // Pilot UUUD (for passenger to pilot messages)
                } else if ((agentC != NULL_KEY) && (agent == NULL_KEY) && (ivagent == NULL_KEY)) {
                    if (checkAccess(agentC)) {
//llOwnerSay("Valid pilot sits.");
                        agent = agentC;
                        //  Initialise vehicle properties
                        llMessageLinked(LINK_THIS, LM_VX_INIT, "", NULL_KEY);

                        //  Avatar has sat on the control seat
                        sitLinkPilot = llGetNumberOfPrims();    // Link of seated pilot
regionChangeControls = FALSE;
                        llRequestPermissions(agent, pilotPerms);
                        exPassenger = NULL_KEY;         // Forget ex passenger
                        stable = FALSE;                 // Mark controls unstable, start counter
                        stableCount = 0;
                        autoSAMtime = 0;                // Schedule an immediate SAM threat probe
                        autoRangeTime = 0;              // Schedule an immediate range update
                        stuckCount = 0;                 // Reset stuck count

                        //  Reset mission statistics
                        statRegionX = 0;    // Regions crossed
                        statDistance = 0;   // Distance travelled
                        statLpos = llGetRegionCorner() + llGetPos();
                        statLand = 0;       // Auto-landings performed
                        statCollO = 0;      // Collisions with objects
                        statCollT = 0;      // Collisions with terrain
                        statSAM = 0;        // SAM diverts
                        statDests = 0;      // Destinations arrived at
                        statDrop = 0;       // Anvils dropped
                        T_nhits = T_nscore = 0; // Bombing score

                        //  Broadcast key of new pilot
                        llMessageLinked(LINK_THIS, LM_PI_PILOT, "", agent);

                        //  Initialise Region Crossing handler
                        llMessageLinked(LINK_THIS, LM_RX_INIT, (string) lPilot, agent);

                        //  Initialise Script Processor
                        llMessageLinked(LINK_THIS, LM_SP_INIT, "", agent);

                        //  Save pilot's relative position and rotation
                        pPos = llList2Vector(llGetLinkPrimitiveParams(llGetNumberOfPrims(),
                            [ PRIM_POS_LOCAL ]), 0);
                        pRot = llList2Rot(llGetLinkPrimitiveParams(llGetNumberOfPrims(),
                            [ PRIM_ROT_LOCAL ]), 0);

                        //  Set pilot's name in name of vehicle
                        llSetLinkPrimitiveParamsFast(LINK_ROOT, [ PRIM_NAME,
                            nameOrig + ": " + llKey2Name(agent) ]);

                        llSetStatus(STATUS_PHYSICS, TRUE);
                        statMETstart = llGetTime();     // Start of mission time

                        //  Start the event timer
                        llSetTimerEvent(0.1);
                        llResetTime();                  // Reset script elapsed time

                        //  Listen for target hit events
                        hitH = llListen(hitChannel, "", "", "");

                        eStopped = FALSE;
                        if (volume > 0) {
/* IF ROCKET  */
                            llPlaySound("Engine start", volume);
                            //  Set timer to switch from start sound to running loop
                            starting = TRUE;            // Set engine starting
                            tStarting = llGetTime() + 4; // Set switch to engine loop time
/* END ROCKET */
/* IF UFO 
                            llLoopSound("Engine flight", volume);
/* END UFO */
                        }

                        llCollisionSound("", 0);        // We handle our own collisions
                        llMessageLinked(lSaddle, LM_SO_PRELOAD, "Collision_boing", agent);
                        llMessageLinked(lSaddle, LM_SO_PRELOAD, "Collision_scrape", agent);

/* IF ROCKET  */
                        //  Set nozzle combustion colour and glow
                        llSetLinkPrimitiveParamsFast(lNozzle,
                            [ PRIM_COLOR, 2, <1, 0.5, 0>, 1 ]);
                        llSetLinkPrimitiveParamsFast(lNozzle,
                            [ PRIM_GLOW, 2, 0.5 ]);
/* END ROCKET */
                    } else {
//llOwnerSay("Invalid pilot sits.");
                        ivagent = agentC;
                        llRegionSayTo(agentC, PUBLIC_CHANNEL,
                            "You are not allowed to fly this vehicle.");
                        llUnSit(ivagent);
                        return;
                    }
                } else if ((passengerC != NULL_KEY) && (passenger == NULL_KEY)) {
                    //  Passenger has joined the pilot, sitting in passenger seat
//llOwnerSay("Passenger sits.");
                    passenger = passengerC;
                    if (ivagent != NULL_KEY) {
                        return;                     // Just a simple sit if pilot invalid
                    }
                    llMessageLinked(LINK_THIS, LM_PA_SIT,
                        llList2Json(JSON_ARRAY, [
                            passenger,              // Passenger UUID
                            lPassenger,             // Link on which passenger seated
                            sitLinkPassenger,       // Link number of seated avatar
                            1                       // Passenger number: 1 -- n
                        ]), agent);                 // Pilot UUUD (for passenger to pilot messages)
                }
            }

            //  Inform Region Crossing of the change
            if ((change & (CHANGED_LINK | CHANGED_REGION)) != 0) {
                llMessageLinked(LINK_THIS, LM_RX_CHANGED,
                    llList2Json(JSON_ARRAY, [ change, 2, lPilot, lPassenger ]), NULL_KEY);
            }
        }

        listen(integer channel, string name, key id, string message) {
            if (channel == hitChannel) {
                list msg = llJson2List(message);
                string ccmd = llList2String(msg, 0);

                //  HIT:  Hit report from target

                if (ccmd == "HIT") {
                    key T_okey = llList2Key(msg, 1);                // Key of projectile owner
                    if (T_okey == owner) {                          // Is is this a hit by us ?
                        T_nhits = llList2Integer(msg, 2);           // Total hits
                        integer T_score = llList2Integer(msg, 3);   // Score for this hit
                        T_nscore = llList2Integer(msg, 4);          // Total score for all hits
                        integer T_range = llList2Integer(msg, 5);   // Range of hit
                        //integer T_channel = llList2Integer(msg, 6);   // Target's command channel
                        //key T_key = llList2String(msg, 7);        // Target key

                        tawk("Hit!  Score " + (string) T_score + "  Range " + (string) T_range +
                            "  Total hits " + (string) T_nhits + "  score " + (string) T_nscore);
                    }
                }
            }
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//ttawk("Pilotage link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_VX_HEARTBEAT (15): Request heartbeat
            if (num == LM_VX_HEARTBEAT) {
                if (str == "REQ") {
                    llMessageLinked(LINK_THIS, LM_VX_HEARTBEAT, "PILOTAGE", NULL_KEY);
                }

            //  LM_PI_INIT (20): Initialise pilotage

            } else if (num == LM_PI_INIT) {

            //  LM_PI_RESET (21): Reset script

            } else if (num == LM_PI_RESET) {
                llResetScript();

            //  LM_PI_STAT (22): Report Pilotage status

            } else if (num == LM_PI_STAT) {
                vector fwd = llRot2Up(llGetLocalRot());
                list edge = regionEdge(llGetPos(), fwd);
                list quad = quadrant(fwd);
                float cor = regCorner(fwd);
                llMessageLinked(LINK_THIS, LM_VX_PISTAT,
                    llList2Json(JSON_ARRAY, [
                        statMETstart, statMETlast, statDistance,
                        statRegionX, statDests, statLand, statSAM,
                        statCorner, statCollO, statCollT, statDrop,
                        T_nhits, T_nscore,
                        fwd, llList2Float(edge, 0), llList2String(edge, 1),
                        llList2String(quads, llList2Integer(quad, 0)), cor,
                        llGetFreeMemory(), llGetUsedMemory(),
                        agent, llGetPermissions(), llGetPermissionsKey()
                                            ]),
                id);

            //  LM_PI_DEST (23): Set destination

            } else if (num == LM_PI_DEST) {
                list de = llJson2List(str);
                destRegion = llList2String(de, 0);          // Region name
                destGrid = (vector) llList2String(de, 1);   // Region grid co-ordinates
                destRegc = (vector) llList2String(de, 2);   // Destination co-ordinates in region

            //  LM_PI_SETTINGS (24): Update settings from command processor

            } else if (num == LM_PI_SETTINGS) {
                list s = llJson2List(str);
                autoCruiseAlt = llList2Float(s, 0);         // 0: Cruise altitude
                autoAltTolerance = llList2Float(s, 1);      // 1: Altitude tolerance
                autoRangeTolerance = llList2Float(s, 2);    // 2: Range tolerance
                smokeColour = (vector) llList2String(s, 3); // 3: Smoke colour
                smokeAlpha = llList2Float(s, 4);            // 4: Smoke transparency
                volume = llList2Float(s, 5);                // 5: Engine sound volume
                showPanel = llList2Integer(s, 6);           // 6: Show control panel ?
                X_THRUST = llList2Float(s, 7);              // 7: X thrust
                Z_THRUST = llList2Float(s, 8);              // 8: Z thrust
                restrictAccess = llList2Integer(s, 9);      // 9: Access restriction: owner, group, public
                tfObstacles = llList2Integer(s, 10);        // 10: Terrain following: evade obstacles ?
                autoSAMinterval = llList2Float(s, 11);      // 11: SAM threat probe interval

            //  LM_PI_ENGAGE (25): Engage/disengage autopilot

            } else if (num == LM_PI_ENGAGE) {
                integer wasEngaged = autoEngaged;
                list en = llJson2List(str);
                autoEngaged = llList2Integer(en, 0);        // Autopilot engaged ?
                autoLand = llList2Integer(en, 1);           // Auto-land in progress ?
                autoLandEnable = llList2Integer(en, 2);     // Auto-land upon arrival enabled ?
                autoSuspendExp = llList2Integer(en, 3);     // Suspend expiry time
                scriptActive = llList2Integer(en, 4);       // Is script active ?
                scriptSuspend = llList2Integer(en, 5);      // Is script suspended ?
                if (wasEngaged && (volume > 0)) {
/* IF ROCKET  */
                    llPlaySound("Engine stop", volume);
/* END ROCKET */
/* IF UFO 
                    llStopSound();
/* END UFO */
                }
                if (autoEngaged && (!wasEngaged)) {
                    velDestSmooth = -9999;                   // Reset velocity toward destination
                }

            //  LM_PI_FIRE (26): Fire weapon / handle impact

            } else if (num == LM_PI_FIRE) {
                if (str == "FIRE") {
                    fire();
                } else if ((llGetSubString(str, 0, 3) == "SAM:") &&
                           (agent != NULL_KEY)) {
                    string act = llGetSubString(str, 4, 5);

                    if (act == "di") {              // Disable
                        tawk("Disabled by SAM site " + llGetSubString(str, 7, -1) + ".  Stand to restore.");
                        //  Disengage autopilot
                        autoDisengage();

                        //  If script is active, terminate it
                        if (scriptActive) {
                            scriptActive = scriptSuspend = FALSE;
                            llMessageLinked(LINK_THIS, LM_SP_INIT, "", whoDat); // Reset Script Processor
                        }
                        
                        //  Helm, full stop!
                        llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION,
                            ZERO_VECTOR);
                        llSetVelocity(ZERO_VECTOR, FALSE);
                        llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION,
                            ZERO_VECTOR);
                        llSetAngularVelocity(ZERO_VECTOR, FALSE);

                        //  Release pilot's control authority
                        llReleaseControls();

                        starting = FALSE;               // Just in case we're still starting
                        eStopped = TRUE;                // Mark engine stopped
                        if (volume > 0) {
/* IF ROCKET  */
                            llPlaySound("Engine stop", volume);
/* END ROCKET */
/* IF UFO 
                            llStopSound();
/* END UFO */
                        }

/* IF ROCKET  */
                        //  Return nozzle to engine off
                        llSetLinkPrimitiveParamsFast(lNozzle,
                            [ PRIM_COLOR, 2, <0.15, 0.15, 0.15>, 1 ]);
                        llSetLinkPrimitiveParamsFast(lNozzle, [ PRIM_GLOW, 2, 0 ]);

                        //  Make sure smoke is off
                        smoke(FALSE);
/* END ROCKET */
                    } else if (act == "ej") {       // Eject
                        llPlaySound("Bomb explosion", 1);
                        eStopped = TRUE;            // Mark engine stopped
                        llUnSit(agent);
                    } else if (act == "ex") {       // Explode
                        //  CAUTION!  This destroys the vehicle with no backup
                        llPlaySound("Bomb explosion", 1);
                        llDie();
                    } else if (act == "wa") {       // Warn
                        tawk("Attacked by SAM site " + llGetSubString(str, 7, -1));
                    }
                }

            //  LM_PI_TARGCLR (28): Clear target statistics

            } else if (num == LM_PI_TARGCLR) {
                if (agent != NULL_KEY) {
                    statDrop = T_nhits = T_nscore = 0;
                    llRegionSay(targetChannel, "Clear for " + (string) agent);
                } else {
                    whoDat = id;
                    tawk("No pilot on board.");
                }

            //  LM_PI_MENDCAM (29): Recover permissions, controls, and camera

            } else if (num == LM_PI_MENDCAM) {
regionChangeControls = FALSE;
                llReleaseControls();
                llRequestPermissions(agent, pilotPerms);

            //  LM_TF_TERRAIN (74): Terrain report

            } else if (num == LM_TF_TERRAIN) {
                list tr = llJson2List(str);
                tfTerrain = llList2Float(tr, 0);            // Terrain altitude
                float tfObs = llList2Float(tr, 1);          // Obstacle avoidance altitude
                if (tfObstacles) {
                    tfTerrain += tfObs;                     // If enabled, avoid obstacles
                }


            //  LM_SA_DIVERT (97): Divert waypoint from SAM Sites

            } else if (num == LM_SA_DIVERT) {
                list wp = llJson2List(str);
                if (llGetListLength(wp) > 0) {
                    if (!autoDivertActive) {
                        statSAM++;
                    }
                    autoDivertActive = TRUE;
                    autoDivertRange = llList2Float(wp, 1);          // Range to threat
                    autoDivertG = (vector) llList2String(wp, 2);    // Grid waypoint
                    autoDivertR = (vector) llList2String(wp, 3);    // Region waypoint
                    autoDivertSite = llList2String(wp, 4);          // Label of threat site
                } else {
                    autoDivertActive = FALSE;
                }

            //  LM_TR_SETTINGS (120): Set trace modes

            } else if (num == LM_TR_SETTINGS) {
                trace = (llList2Integer(llJson2List(str), 0) & LM_TR_S_PILOT) != 0;

            }
        }

        /*  We use the timer to transition from the rocket engine start 
            sound clip to the loop for the engine running.

            When the autopilot is engaged, we evaluate our range and
            bearing with respect to the destination and altitude
            above terrain in our path and submit commands to keep us
            on course and out of trouble.  Consequently, a great deal
            of the logic for pilotage with the autopilot engaged will
            be found here.  */

        timer() {

            /*  When we first start listening for controls, we'll usually
                get some random control inputs from heaven knows where.  The
                stableCount timer causes purported control inputs to be
                ignored until stableTicks have elapsed.  */
            if (!stable) {
                stableCount++;
                if (stableCount >= stableTicks) {
                    stable = TRUE;
                }
            }

            float t = llGetTime();          // Get script time stamp
            vector p = llGetPos();
            vector rc = llGetRegionCorner();
            float bear;
            vector fwd = ZERO_VECTOR;

            /*  If we're at the end of the engine start interval, make the
                transition from the starting audio clip to the looped running
                clip.  */

            if ((starting) && (t > tStarting)) {
                starting = FALSE;
/* IF ROCKET  */
                if (volume > 0) {
                    llLoopSound("Engine flight", volume);
                }
/* END ROCKET */
            }

            /*  If autopilot engaged and suspended, re-enable at the end of
                the suspension interval.  */

            if (autoEngaged && (autoSuspendExp > 0) && (t >= autoSuspendExp)) {
                tawk("Autopilot re-enabled.");
                autoSuspendExp = 0;
            }

            //  If autopilot engaged, update and send commands accordingly

            if (autoEngaged && (autoSuspendExp < t)) {
                integer ud = 0;

                /*  Evaluate target bearing and turn if necessary.
                    Note this this automatically allows us to recover
                    after being whacked off course by a region crossing.
                    If a divert waypoint is in effect due to a SAM threat,
                    use that as the intermediate destination.  */

                autoTurn = FALSE;
                vector tposi;
                
                if (autoCornerDivert) {
                    tposi = rc + cornerDivertPos;
                    tposi.z = 0;
                } else if (autoDivertActive) {
                    tposi = < (autoDivertG.x * REGION_SIZE) + autoDivertR.x,
                              (autoDivertG.y * REGION_SIZE) + autoDivertR.y, 0 >;
                } else {
                    tposi = < (destGrid.x * REGION_SIZE) + destRegc.x,
                              (destGrid.y * REGION_SIZE) + destRegc.y, 0 >;
                }
                vector tbear = tposi - (rc + p);
                tbear.z = 0;
                vector tbearn = llVecNorm(tbear);
                fwd = llRot2Up(llGetLocalRot());
                float bow = llAcos(tbearn * fwd);
                vector bdir = tbearn % fwd;
                bear = bow;
                if (bdir.z < 0) {
                    bear = TWO_PI - bear;
                }
                autoRange = llVecMag(tbear);
                //  Have we arrived within autoRangeTolerance of destination ?
                integer autoArrived = autoRange <= autoRangeTolerance;
                //  Do we need to fly up to altitude of destination ?
                integer autoFlyUp = autoArrived && (p.z < destRegc.z);
                autoTurnAuth = llFabs(bdir.z);      // Set turn control authority
                if (bow > (TWO_PI / 3)) {
                    autoTurnAuth = 1;
                }

                /*  If we aren't landing, haven't arrived at the horizontal
                    destination, and the target angle on the bow is larger
                    than the dead band in bearing, crank in rudder control
                    to aim toward the destination.  */

                if (!autoLand) {
                    if ((bow > autoDeadBand) && (!autoArrived)) {
                        autoTurn = TRUE;
                        if (bdir.z < 0) {
                            ud = ud | CONTROL_LEFT;
                        } else {
                            ud = ud | CONTROL_RIGHT;
                        }
                    }
                }

                /*  If the bearing is within tolerance, move forward
                    to reduce range.  When we begin to approach the
                    destination, throttle the forward thrust so we don't
                    overshoot the target.  */

                if (!autoLand) {
                    if (!autoArrived) {
                        if (bow <= autoDeadBand) {
                            ud = ud | CONTROL_FWD;
                            if (autoRange < 100) {
                                //  Proportionally adjust thrust by range to target
                                autoThrustAuth = autoRange / 100;
                            } else {
                                autoThrustAuth = 1;
                            }
                        }

                    } else {
                        /*  We have arrived at the destination.  If we
                            are at or above the destination's altitude
                            either commence the auto-land sequence or else
                            disengage the autopilot (as we've reached an
                            en route waypoint).  If we're below the destination
                            altitude, we haven't had time to climb to its
                            altitude, so continue to climb vertically to
                            reach it.  */
                        if (autoDivertActive) {
                            /*  If we have arrived at a waypoint inserted to
                                divert around a SAM threat, mark the divert
                                complete, restoring the original destination,
                                and reset the timer to perform an immediate
                                new SAM threat scan.  */
                            autoDivertActive = FALSE;
                            autoSAMtime = 0;
                            ttawk("SAM divert complete.");
                        } else {
                            if (!autoFlyUp) {
                                statDests++;
                                if (autoLandEnable) {
                                    autoLand = TRUE;
                                    tawk("Autoland in progress.");
                                } else {
                                    autoDisengage();
                                }
                            }
                        }
                    }
                }

                //  In cruise, adjust altitude above terrain if necessary to autoCruiseAlt

                if (autoLand) {
                    autoDz = destRegc.z - p.z;
                } else {
                    /*  If we're performing a fly-up to reach the destination
                        altitude, target it instead of the cruising altitude.  */
                    if (autoFlyUp) {
                        autoDz = (destRegc.z - p.z) + autoAltTolerance;
                    } else {
                        autoDz = (tfTerrain + autoCruiseAlt) - p.z;
                    }
                }
                if (llFabs(autoDz) > autoAltTolerance) {
                    if (autoDz < 0) {
                        ud = ud | CONTROL_DOWN;
                    } else {
                        ud = ud | CONTROL_UP;
                    }
                } else {
                    if (autoLand) {
                        statLand++;
                        autoDisengage();
                        autoLand = FALSE;
                    }
                }

                /*  Test if we're close to a region crossing.  If so, remove any forward
                    input and coast across the crossing at a slower speed to avoid
                    problems.  */

                float autoRegionEdge = 25;          // Threshold for approaching region edge, metres
                float autoRegionMinVel = 1;         // Minimum velocity for crossing regions
                float autoRegionCorner = 2 * DEG_TO_RAD; // Angular threshold for path approaching region corner
                vector rfwd = llRot2Up(llGetLocalRot());
                if (llList2Float(regionEdge(llGetPos(), rfwd), 0) < autoRegionEdge) {
                    if (!autoThrottleDown && (regCorner(rfwd) < autoRegionCorner)) {
                        /*  Our path takes us dangerously close to the corner
                            formed by four regions.  Crossing there is particularly
                            perilous, since different we might end up making two
                            or more region crossings at once, or the vehicle and
                            occupants might end up in different regions.  If we
                            find ourselves in this situation, compute a divert
                            waypoint, just as we do for SAM sites, which takes us
                            cleanly across an edge sufficiently distant from the
                            corner which causes the smallest diversion from our
                            desired course.  */
                        list quad = quadrant(rfwd); // Get quadrant and corner
                        float CORNER_THREAT = 25;   // Go no closer than this to corner, metres
                        vector sbear = llList2Vector(quad, 1) - p;  // Bearing to corner
                        sbear.z = 0;
                        vector sbearn = llVecNorm(sbear);   // Corner bearing, normalised
                        vector throff = (sbearn % <0, 0, 1>) * CORNER_THREAT;
                        vector threat1 = sbear + throff;
                        vector threat2 = sbear - throff;
                        vector cornerDivertVec = threat1;   // Choose divert closest to our path
                        if (llVecMag(threat2 % tbearn) < llVecMag(threat1 % tbearn)) {
                            cornerDivertVec = threat2;
                        }
                        list redge = regionEdge(p, cornerDivertVec);
                        cornerDivertPos = p + (llVecNorm(cornerDivertVec) * llList2Float(redge, 0));
                        autoCornerDivert = TRUE;            // Set corner divert active
                        statCorner++;
                        ttawk("Approaching " +
                            llList2String(quads, llList2Integer(quad, 0)) + " region corner." +
                            "  Divert to: " + (string) cornerDivertPos + " vec " + (string) cornerDivertVec);
                    }
                    if (llVecMag(llGetVel()) > autoRegionMinVel) {
                        ud = ud & (~CONTROL_FWD);
                        if (!autoThrottleDown) {
                            autoThrottleDown = TRUE;
                            ttawk("Region crossing: throttle down.");
                        }
                    }
                } else {
                    if (autoThrottleDown) {
                        autoThrottleDown = FALSE;
                        ttawk("Region crossing: throttle up.");
                    }
                }

                //  Now apply the control inputs computed by the autopilot

                if (ud != 0) {
                    processControl(ud | CONTROL_AUTOPILOT, ud & (CONTROL_FWD | CONTROL_BACK));

                    //  See if we're stalled, usually at a void sim boundary

                    if ((ud & CONTROL_FWD) && ((ud & (CONTROL_RIGHT | CONTROL_LEFT)) == 0)) {
                        float edge = REGION_SIZE * 0.025;           // Threshold defining region edge
                        vector vel = llGetVel();
                        //  Velocity projected on vector to destination
                        float veldest = vel * tbearn;
                        //  Exponentially smoothed velocity toward destination
                        if (velDestSmooth == -9999) {
                            velDestSmooth = veldest;                // Set first time prior to first measurement
                        }
                        velDestSmooth = velDestSmooth + 0.3 * (veldest - velDestSmooth);

                        //  Are we near the edge of the current region ?
                        if (((p.x <= edge) || ((REGION_SIZE - p.x) <= edge)) ||
                            ((p.y <= edge) || ((REGION_SIZE - p.y) <= edge))) {
                            float PROGRESS = 1.0;                   // Criterion for making progress
                            if (velDestSmooth < PROGRESS) {
                                if (stuckCount == 0) {
                                    stuckStart = llGetTime();
                                }
                                stuckCount++;
                                float stuckTime = llGetTime() - stuckStart;
//            llOwnerSay("Stuck at " + llGetRegionName() + " " + (string) p + ".  Velocity " + (string) velDestSmooth +
//                "  Count " + (string) stuckCount + "  Time " + (string) stuckTime);
                                if ((stuckTime >= stalledTime) && (!stalledWarn)) {
                                    tawk("Stalled, probably at a void sim.  Override autopilot and escape manually.");
                                    stalledWarn = TRUE;
                                }
                            } else {
//            if (stuckCount > 0) {
//                llOwnerSay("Reset stuckCount by progress " + (string) velDestSmooth + " m/sec");
//            }
                                stuckCount = 0;
                            }
                        } else {
//        if (stuckCount > 0) {
//            llOwnerSay("Reset stuckCount by position " + (string) p);
//        }
                            stuckCount = 0;
                        }
                    }
                    if (stuckCount == 0) {
                        stalledWarn = FALSE;
                    }
                }

                //  If it's time, probe SAM site evasion

                if (autoSAMinterval > 0) {
                    if (t > autoSAMtime) {
                        vector np = rc + llGetPos();
                        statDistance += llVecDist(statLpos, np);
                        statLpos = np;
                        //  Only probe when not landing or turning
                        if ((!autoLand) && (!autoTurn)) {
                            autoSAMtime = t + autoSAMinterval;
                            llMessageLinked(LINK_THIS, LM_SA_PROBE,
                                llList2Json(JSON_ARRAY, [ rc, p,
                                    destGrid * REGION_SIZE, destRegc ]), agent);
                        }
                    }
                }
            } else {

                //  If it's time, update the integrated distance travelled

                if (t > updateDistTime) {
                    updateDistTime = t + updateDistInterval;
                    vector np = rc + p;
                    statDistance += llVecDist(statLpos, np);
                    statLpos = np;
                }

                /*  In manual flight, if it's time, perform a SAM site
                    threat scan and inform the pilot via the panel
                    of the nearest threat along the current course.  */

                if (showPanel && (autoSAMinterval > 0)) {
                    if (t > autoSAMtime) {
                        autoSAMtime = t + autoSAMinterval;
                        llMessageLinked(LINK_THIS, LM_SA_PROBE,
                            llList2Json(JSON_ARRAY, [ rc, p, rc,
                                p + llRot2Up(llGetLocalRot()) ]), agent);
                    }
                }
            }

            //  If it's time, update the pilot's control panel
            if (showPanel && (t > autoRangeTime)) {
                autoRangeTime = t + autoRangeInterval;
                //  Show range to true destination even if SAM divert is active
                vector tposi = < (destGrid.x * REGION_SIZE) + destRegc.x,
                                 (destGrid.y * REGION_SIZE) + destRegc.y, 0 >;
                vector tbear = tposi - (rc + p);
                tbear.z = 0;
                float trueRange = llVecMag(tbear);
                if (!autoEngaged) {
                    fwd = llRot2Up(llGetLocalRot());
                    tfTerrain = max(llGround(ZERO_VECTOR), llWater(ZERO_VECTOR));
                    if (destRegion != "") {
                        vector tbearn = llVecNorm(tbear);
                        vector bdir = tbearn % fwd;
                        bear = llAcos(tbearn * fwd);
                        if (bdir.z < 0) {
                            bear = TWO_PI - bear;
                        }
                        vector vel = llGetVel();
                        //  Velocity projected on vector to destination
                        float veldest = vel * tbearn;
                        //  Exponentially smoothed velocity toward destination
                        if (velDestSmooth == -9999) {
                            velDestSmooth = veldest;    // Set first time prior to first measurement
                        }
                        velDestSmooth = velDestSmooth + 0.3 * (veldest - velDestSmooth);
                    } else {
                        //  If autopilot off and no destination set, just show actual speed
                        velDestSmooth = llVecMag(llGetVel());
                    }
                }
                //  Vehicle Auxiliary actually composes and updates the panel
                llMessageLinked(LINK_THIS, LM_VX_PIPANEL,
                    llList2Json(JSON_ARRAY, [
                        fwd, p, tfTerrain,
                        destRegion, trueRange, bear,
                        velDestSmooth, stalledWarn,
                        autoDivertActive, autoEngaged, autoDivertSite, autoDivertRange,
                        autoCornerDivert, cornerDivertPos,
                        statDrop, T_nhits, T_nscore
                                            ]),
                    agent);
            }
        }

        //  Collision with another object

        collision(integer nDetected) {
            if (agent != NULL_KEY) {
                integer lGen;
                integer i;
                integer nGenuine = 0;
                key dk = llDetectedKey(i);
                for (i = 0; i < nDetected; i++) {
                    /*  On turbulent region crossings, it is possible to receive
                        reports of "collisions" with the pilot or passenger before
                        they are properly re-seated on the vehicle.  Check for this
                        case and ignore them.  */
                    if ((dk != agent) && (dk != passenger) && (dk != exPassenger)) {
                        nGenuine++;
                        lGen = i;
                    }
                }
                if (nGenuine > 0) {
                    key k = llDetectedKey(lGen);
                    float t = llGetTime();

                    /*  Only report collisions with new objects or at
                        least a second after the last collision with the
                        same object.  */
                    if ((k != lastObjectCollisionKey) || ((t - lastObjectCollision) > 1)) {
                        lastObjectCollisionKey = k;
                        lastObjectCollision = t;
                        statCollO++;
                        tawk("Collided with " + llDetectedName(lGen));
                        if (volume > 0) {
                            llMessageLinked(lSaddle, LM_SO_PLAY,
                                (string) volume + ", Collision_boing", agent);
                        }
                    }

                    if (autoEngaged && (autoSuspendExp < llGetTime())) {
                        key colK = llDetectedKey(lGen);
                        if (colK != autoCollide) {
                            autoCollide = colK;
                            autoCollideCount++;
                        } else {
                            autoCollideCount++;
                        }
                        if (autoLand) {
                            autoDisengage();
                        } else {
                            //  Perform autopilot back-up and fly-up after collision
                            processControl(CONTROL_UP | CONTROL_BACK |
                                           CONTROL_AUTOPILOT | CONTROL_COLLISION, 0);
                        }
                    }
                }
            }
        }

        //  Collision with terrain

        land_collision(vector where) {
            /*  Land collision events tend to come in bursts of many
                rapid-fire reports.  We limit the rate at which we
                report them so the collision sound can play to conclusion
                and we don't overload the audio rate limit.  */
            float t = llGetTime();
            if ((t - lastTerrainCollision) > 1) {
                lastTerrainCollision = t;
                statCollT++;
                if (volume > 0) {
                    llMessageLinked(lSaddle, LM_SO_PLAY, (string) volume + ", Collision_scrape", agent);
                }
                if (autoEngaged && (autoSuspendExp < llGetTime()) && (!autoLand)) {
                    tawk("Terrain!  Pull up, pull up!");
                    autoDz = autoAltTolerance * 3;
                    processControl(CONTROL_UP | CONTROL_AUTOPILOT, 0);
                }
            }
        }

        //  Touch: drop anvil bomb

        touch_start(integer total_number) {
            integer i;

            for (i = 0; i < total_number; i++) {
                if ((llDetectedKey(i) == agent) ||
                    (llDetectedKey(i) == passenger)) {
                    fire();
                }
            }
        }
    }
