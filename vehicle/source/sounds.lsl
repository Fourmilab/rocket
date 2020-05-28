    /*

                       Sounds

                    by John Walker

    */

    //  Sounds Messages
    integer LM_SO_INIT = 40;        // Initialise
    integer LM_SO_RESET = 41;       // Reset script
    integer LM_SO_STAT = 42;        // Print status
    integer LM_SO_PLAY = 43;        // Play sound
    integer LM_SO_PRELOAD = 44;     // Preload sound
    integer LM_SO_FLASH = 45;       // Explosion particle effect

    //  Pilotage messages
    integer LM_PI_PILOT = 27;       // Pilot sit / unsit

    //  Trace messages
    integer LM_TR_SETTINGS = 120;   // Broadcast trace settings
    //  Trace module selectors
    integer LM_TR_S_SOUND = 32;     // Sounds

    key owner;                      // Owner of the vehicle
    key agent = NULL_KEY;           // Pilot, if any
    integer trace;                  // Generate trace output ?

    /*  tawk  --  Send a message to the interacting user in chat.
                  The recipient of the message is defined as
                  follows.  If an agent is on the pilot's seat,
                  that avatar receives the message.  Otherwise,
                  the message goes to the owner of the object.
                  In either case, if the message is being sent to
                  the owner, it is sent with llOwnerSay(), which isn't
                  subject to the region rate gag, rather than
                  llRegionSayTo().  */
/* IF SOUND_TRACE  */
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
/* END SOUND_TRACE */

    //  Create particle system for explosion effect

    splodey() {
        llLinkParticleSystem(LINK_THIS, [
            PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,

            PSYS_SRC_BURST_RADIUS, 0.1,

            PSYS_PART_START_COLOR, <1, 1, 1>,
            PSYS_PART_END_COLOR, <1, 1, 1>,

            PSYS_PART_START_ALPHA, 0.9,
            PSYS_PART_END_ALPHA, 0.0,

            PSYS_PART_START_SCALE, <0.3, 0.3, 0>,
            PSYS_PART_END_SCALE, <0.1, 0.1, 0>,

            PSYS_PART_START_GLOW, 1,
            PSYS_PART_END_GLOW, 0,

            PSYS_SRC_MAX_AGE, 0.75,
            PSYS_PART_MAX_AGE, 0.5,

            PSYS_SRC_BURST_RATE, 20,
            PSYS_SRC_BURST_PART_COUNT, 1000,

            PSYS_SRC_ACCEL, <0, 0, 0>,

            PSYS_SRC_BURST_SPEED_MIN, 2,
            PSYS_SRC_BURST_SPEED_MAX, 2,

            PSYS_PART_FLAGS, 0
                | PSYS_PART_EMISSIVE_MASK
                | PSYS_PART_INTERP_COLOR_MASK
                | PSYS_PART_INTERP_SCALE_MASK
                | PSYS_PART_FOLLOW_VELOCITY_MASK
        ]);
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//llOwnerSay("Sounds link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_SO_INIT (40): Initialise

            if (num == LM_SO_INIT) {

            //  LM_SO_RESET (41): Reset script

            } else if (num == LM_SO_RESET) {
                llResetScript();

            //  LM_SO_STAT (42): Report status

            } else if (num == LM_SO_STAT) {
                string stat = "";

                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "Sound script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";

                llRegionSayTo(id, PUBLIC_CHANNEL, stat);

            //  LM_SO_PLAY (43): Play sound clip

            } else if (num == LM_SO_PLAY) {
                integer comma = llSubStringIndex(str, ",");
                float volume = (float) llGetSubString(str, 0, comma - 1);
                string clip = llStringTrim(llGetSubString(str, comma + 1, -1), STRING_TRIM);
                llPlaySound(clip, volume);
/* IF SOUND_TRACE */
                if (trace) {
                    tawk("Play sound: \"" + clip + "\" volume " + (string) volume);
                }
/* END SOUND_TRACE */

            //  LM_SO_PRELOAD (44): Preload sound clip

            } else if (num == LM_SO_PRELOAD) {
                llPreloadSound(str);                // Note that script sleeps for 1 second
/* IF SOUND_TRACE */
                if (trace) {
                    tawk("Preload sound: \"" + str + "\"");
                }
/* END SOUND_TRACE */

            //  LM_SO_FLASH (45): Explosion particle system effect

            } else if (num == LM_SO_FLASH) {
                /*  If you want to display multiple visual effects, pass
                    parameters specifying them via the str argument.  */
                splodey();
                llSetTimerEvent(1);                 // Set timer to cancel particle system
/* IF SOUND_TRACE */
                if (trace) {
                    tawk("Display explosion");
                }
/* END SOUND_TRACE */

            //  LM_PI_PILOT (27): Set pilot agent key

            } else if (num == LM_PI_PILOT) {
                agent = id;

            //  LM_TR_SETTINGS (120): Set trace modes

            } else if (num == LM_TR_SETTINGS) {
                trace = (llList2Integer(llJson2List(str), 0) & LM_TR_S_SOUND) != 0;
            }
        }

        //  The timer is used to cancel the particle system

        timer() {
            llLinkParticleSystem(LINK_THIS, [ ]);
            llSetTimerEvent(0);                     // Cancel the timer
        }
    }
