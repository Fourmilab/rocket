    /*

                               Anvil Bomb

        This is a gravity bomb version of the anvil projectile used
        by the Anvil Tosser.  It is substantially simpler since it
        simply falls straight down and doesn't move on a parabolic
        trajectory.  Since it's falling vertically, impact markers
        are always placed flat as opposed to oriented toward the
        avatar who tossed the projectile.

        The silliness with the "dynamic" flag is so that we enable
        physics when the projectile is rezzed manually in order to
        edit it without it immediately colliding with something and
        deleting itself.  When we're rezzed manually, the state_entry
        argument of the on_rez() event will be FALSE/0, and we disable
        all collision logic.  When the launcher rezzes us, it passes
        the projectile's lifetime in seconds as this argument, so we
        know to behave as an ephemeral projectile.

    */

    integer dynamic = FALSE;                // Were we rezzed by the launcher ?
    string Bomb_drop = "Bomb drop";         // Bomb dropping sound
    string Collision = "Balloon_Pop";       // Collision sound clip
    string impactMarker = "Fourmilab Impact Marker";    // Impact marker object from inventory
    string targetName = "Fourmilab Target";             // Name of cooperating target
    integer impactMarkerLife = 30;          // Lifetime of impact markers (seconds)
    vector initColour = < 0.5, 0.5, 0.5 >;  // Initial colour

    //  Create particle system for impact effect

    splodey() {
        llParticleSystem([
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

            PSYS_SRC_MAX_AGE, 0.1,
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

    //  Impact with an object or terrain

    impact(integer terrain, integer target) {
        if (dynamic) {
            llSetStatus(STATUS_PHANTOM, TRUE);
            vector pos = llGetPos();
            llMoveToTarget(pos, 0.3);           // Move to where we hit smoothly
            llSetColor(initColour, ALL_SIDES);

            /*  If the collision was not with a designated
                target (which we cleverly determine by looking
                at its prim name), place an impact
                marker and indicate the impact with sound and
                particle effects.  If we hit a target, let the
                target handle the theatrics.  */

            if (!target) {
                //  Place an impact marker where we hit, lying flat on ground
                vector mpos = pos;
                if (terrain) {
                    //  If terrain collision, snap marker to ground height
                    mpos.z = llGround(ZERO_VECTOR) + 0.05;
                }
                llRezObject(impactMarker, mpos, ZERO_VECTOR, ZERO_ROTATION, 700 + impactMarkerLife);
                llPlaySound(Collision, 4);
                splodey();
            }
            llSetTimerEvent(0.1);
        }
    }

    default {
        state_entry() {
            llSetStatus(STATUS_DIE_AT_EDGE, TRUE);
        }

        on_rez(integer start_param) {
            dynamic = start_param > 0;          // Mark if we were rezzed by the launcher
            if (dynamic) {
                llPlaySound(Bomb_drop, 1.0);    // Start the bomb dropping sound
                llSetBuoyancy(0);               // Make projectile fall with gravity
                llCollisionSound("", 1.0);      // Disable collision sounds
                llSetTimerEvent((float) start_param); // Time until projectile deletes itself
                llSetStatus(STATUS_PHYSICS, TRUE); // Make object obey physics
            }
        }

        //  Collision with an object

        collision_start(integer total_number) {
            impact(FALSE, llGetSubString(llDetectedName(0), 0,
                llStringLength(targetName) - 1) == targetName);
        }

        //  Collision with the ground

        land_collision_start(vector pos) {
            impact(TRUE, FALSE);
        }

        //  We use the timer to die  after impact.

        timer() {
            llDie();
        }
    }
