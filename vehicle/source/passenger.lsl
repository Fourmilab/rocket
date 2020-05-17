    /*

              Fourmilab Rocket Passengers

                    by John Walker

        This script manages passengers seated on a vehicle.  (At
        the moment, the plural is aspirational, since the Fourmilab
        Rocket seats only passenger and this script accommodates only
        one.  However, the techniques can be generalised for vehicles
        with more than one passenger.)  The script manages issues such
        as permissions, avatar animations, and camera positions for
        passengers.  In doing so, it strongly resembles the analogous
        code in the Pilotage script for the vehicle's pilot.

        The reason for this script's existence is not, as is so often
        the case, the 64 Kb memory limit for scripts, but rather a
        fundamental limitation in the way scripts are granted permissions
        to manipulate avatars seated on the objects which contain
        them.  Permissions are requested by llRequestPermissions(),
        specifying the key (UUID) if an avatar.  If the avatar is seated,
        commonly-used permissions such as PERMISSION_TAKE_CONTROLS
        and PERMISSION_TRIGGER_ANIMATION are granted automatically, but
        they still must be requested and received before operations
        which require them are performed.

        The gotcha comes from a bullet point in the documentation of
        llRequestPermissions():

            * Scripts may hold permissions for only one agent at a
              time. To hold permissions for multiple agents you
              must use more than one script.

        This means that if you wish to, for example, apply an animation
        to more than one avatar, to cause it to sit on a seat in the
        vehicle, you have to request PERMISSION_TRIGGER_ANIMATION in a
        separate script for each avatar.  If you, for example, requested
        this permissions for the first avatar who sat on the vehicle (the
        pilot), then requested it for a passenger who subsequently sat,
        you'd lose the permission for the pilot.  Given that animations
        and permissions are sometimes lost on region crossings, this makes
        restoring them a nightmare.  This script completely isolates the
        status of the passenger from that of the pilot, allowing them to
        be managed independently.
    */

    //  Passengers messages
    integer LM_PA_INIT = 60;        // Initialise
    integer LM_PA_RESET = 61;       // Reset script
    integer LM_PA_STAT = 62;        // Print status
    integer LM_PA_SIT = 63;         // Passenger sits on vehicle
    integer LM_PA_STAND = 64;       // Passenger stands, leaving vehicle
    
    //  Pilotage messages
    integer LM_PI_MENDCAM = 29;     // Mend camera tracking

    key passenger = NULL_KEY;       // UUID of seated passenger
    integer lPassenger;             // Link on which passenger seated
    integer sitLinkPassenger;       // Link number of seated avatar
    integer psit = 0;               // Passengers seated on vehicle
    key agent;                      // Pilot UUUD (for passenger to pilot messages)

    integer passPerms;              // Permissions we request

//    integer rchange = FALSE;        // Is this a region change permissions request ?

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            passPerms =  PERMISSION_CONTROL_CAMERA;
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//if ((num >= 60) && (num < 70)) {
//llOwnerSay("Passengers message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);
//}

            //  LM_PA_INIT (60): Initialise

            if (num == LM_PA_INIT) {

            //  LM_PA_RESET (61): Reset script

            } else if (num == LM_PA_RESET) {
                llResetScript();

            //  LM_PA_STAT (62): Report status

            } else if (num == LM_PA_STAT) {
                string stat = "Passenger status:\n";

                if (psit == 0) {
                    stat += "    No passenger.\n";
                } else {
                    stat += "    " + (string) psit + ".  " +
                        (string) passenger + " (" + llKey2Name(passenger) + ")" +
                        " link " + (string) sitLinkPassenger +
                        " on prim link " + (string) lPassenger + "\n" +
                        "    Perms: " + (string) llGetPermissions() + "\n";
                }

                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";

                llRegionSayTo(id, PUBLIC_CHANNEL, stat);

            //  LM_PA_SIT (63): Passenger sits on vehicle

            } else if (num == LM_PA_SIT) {
                list args = llJson2List(str);
                passenger = llList2Key(args, 0);            // Passenger UUID
                lPassenger = llList2Integer(args, 1);       // Link on which passenger seated
                sitLinkPassenger = llList2Integer(args, 2); // Link number of seated avatar
                psit = llList2Integer(args, 3);             // Passenger number: 1 -- n
                agent = id;                                 // Pilot UUID
//                rchange = FALSE;
                llRequestPermissions(passenger, passPerms); // Request permissions

            //  LM_PA_STAND (64): Passenger stands, leaving vehicle

            } else if (num == LM_PA_STAND) {
                list args = llJson2List(str);
                lPassenger = llList2Integer(args, 1);       // Link on which passenger seated
                psit = llList2Integer(args, 3);             // Passenger number: 1 -- n
                agent = id;                                 // Pilot UUID

                passenger = NULL_KEY;
                psit = 0;
                sitLinkPassenger = 0;


            //  LM_PI_MENDCAM (29): Recover permissions, controls, and camera
                
            } else if (num == LM_PI_MENDCAM) {
                if (passenger != NULL_KEY) {
                    llRequestPermissions(passenger, passPerms);
                }
            }
        }

        //  Grant of permissions by passenger avatar

        run_time_permissions(integer perm) {
//llOwnerSay("Obtained passenger permissions: " + (string) perm);

            //  Set passenger's camera position

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

        /*  On region changes, test for loss of passenger permissions
            or active animation and restore if necessary.  */
/*
        changed(integer change) {
            if (change & CHANGED_REGION) {
                if (psit > 0) {
                    rchange = TRUE;
////                    llRequestPermissions(passenger, passPerms);
                }
            }
        }
*/
    }
