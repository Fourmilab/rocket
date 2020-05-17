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

            //  LM_SO_PRELOAD (44): Preload sound clip

            } else if (num == LM_SO_PRELOAD) {
                llPreloadSound(str);                // Note that script sleeps for 1 second

            //  LM_SO_FLASH (45): Explosion particle system effect

            } else if (num == LM_SO_FLASH) {
                splodey();
                llSetTimerEvent(1);                 // Set timer to cancel particle system
            }
        }

        //  The timer is used to cancel the particle system

        timer() {
            llLinkParticleSystem(LINK_THIS, [ ]);
            llSetTimerEvent(0);                     // Cancel the timer
        }
    }
