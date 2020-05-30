    /*

                    Control Recovery Amulet

                    by John Walker (Fourmilab)

        This is a wearable bracelet which attempts to recover
        controls if they are lost when a vehicle the avatar is
        riding is destroyed due to a property ban line or security
        orb.  Also, sometimes controls will be lost after a
        turbulent region crossing that doesn't result in an
        un-seat (the most common symptom of this is forward
        and back controls working but inability to turn).  In
        many (but not all) such cases, this bracelet may allow
        you to recover control authority.

        When attached to an avatar, the bracelet listens for
        commands on local chat channel 77.  Commands are:

            Fix controls
                Request permission to take control of navigation
                keys and, if granted, release them again after
                half a second.  This will, in many cases, recover
                loss of control after an un-seat or messy region
                crossing.  The most common symptom of this loss of
                control is being able to walk forward and back but
                not turn and/or an inability to fly.

            Fix animation
                Sometimes, after an un-seat, a passenger on a vehicle
                will be left stuck in an incorrect animation.  This
                command attempts to terminate a sitting animation and
                restore the default standing animation.  This doesn't
                seem to work as intended.  To do this, you must use
                llUnSit(), but for an avatar attachment this only works
                when the avatar is over land owner by the attachment's
                owner or to which they have group rights.  This means that
                in most cases of un-seats from vehicles crossing third
                party land, the llUnSit() will be silently ignored.  I
                know of no work-around for this at present.s

            Status
                Show status on local chat.  The llGetAgentInfo(),
                llGetPermissions(), and llGetAnimation() values
                for the avatar are reported in local chat.

        All commands and arguments may be abbreviated to the first
        two letters.  Chat commands are accepted only from the
        avatar wearing the bracelet.

        Touching the bracelet requests controls and clicking
        it again releases them.  While controls are taken, the
        bracelet glows and control inputs are echoed in local
        chat.  This is a debugging feature to test taking and
        releasing controls; you should use "Fix controls" in most
        vehicle un-seat situations.

    */

    key owner;                  // Owner / wearer key
    integer commandChannel = 77;    // Command channel in chat
    integer commandH = 0;       // Handle for command channel
    key whoDat = NULL_KEY;      // Avatar who sent command
    integer restrictAccess = 2; // Access restriction: 0 none, 1 group, 2 owner
    integer echo = TRUE;        // Echo chat and script commands ?

    integer grabbed = FALSE;    // Toggle for take/release controls on touch
    integer cmdperm = FALSE;    // Processing permission grants from command ?

    integer fixCtrl = FALSE;    // Fix controls ?
    integer fixAnim = FALSE;    // Fix animations ?
    integer testAnim = FALSE;   // Test animations ?

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

    //  checkAccess  --  Check if user has permission to send commands

    integer checkAccess(key id) {
        return (restrictAccess == 0) ||
               ((restrictAccess == 1) && llSameGroup(id)) ||
               (id == llGetOwner());
    }

    //  abbrP  --  Test if string matches abbreviation

    integer abbrP(string str, string abbr) {
        return abbr == llGetSubString(str, 0, llStringLength(abbr) - 1);
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

        //  Fix animation/controls              Fix specific items

        if (abbrP(command, "fi")) {
            if (argn > 1) {
                string param = llList2String(args, 1);

                //  Fix animation

                if (abbrP(param, "an")) {
                    string an = llGetAnimation(whoDat);
                    if (an != "Standing") {
                        fixAnim = TRUE;
                        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
                    } else {
                        tawk("Already standing.");
                    }

                //  Fix controls

                } else if (abbrP(param, "co")) {
                    cmdperm = TRUE;
                    fixCtrl = TRUE;
                    llRequestPermissions(llGetOwner(), PERMISSION_TAKE_CONTROLS);
                } else {
                    tawk("Unknown fix item.  Valid: animation/controls");
                }
            } else {
                tawk("Fix what?  animation/controls");
            }

        //  Test                                    Run various tests

        } else if (abbrP(command, "te")) {
            if (argn > 1) {
                string param = llList2String(args, 1);

                //  Fix animations

                if (abbrP(param, "an")) {
                    testAnim = TRUE;
                    llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
                } else if (abbrP(param, "si")) {
                    llUnSit(whoDat);
                } else {
                    tawk("Unknown fix item.  Valid: animation/controls");
                }
            } else {
                tawk("Fix what?  animation/controls");
            }

        //  Status                              Print status

        } else if (abbrP(command, "st")) {
            tawk("Control recovery amulet status:\n" +
                 "    Agent Info: " + (string) llGetAgentInfo(whoDat) + "\n" +
                 "    Permissions: " + (string) llGetPermissions() + "\n" +
                 "    Animation: " + llGetAnimation(whoDat) + "\n" +
                 "    Animation list: " + llList2CSV(llGetAnimationList(whoDat))
                );
        }
        return TRUE;
    }

    default {

        on_rez(integer start_param) {
            owner = llGetOwner();
//llOwnerSay("on_rez");
        }

        state_entry() {
            grabbed = FALSE;
            cmdperm = FALSE;
            fixAnim = fixCtrl = FALSE;
//llOwnerSay("State_entry");
            whoDat = llGetOwner();
            if (commandH == 0) {
                commandH = llListen(commandChannel, "", NULL_KEY, "");
                tawk("Listening on /" + (string) commandChannel);
            }
        }

        /*  Handle touch of bracelet.  This toggles taking and releasing
            of controls.  While controls are taken the bracelet will glow
            and control inputs will be echoed in local chat.  This is
            mostly for debugging.  */

        touch_start(integer num_detected) {
//llOwnerSay("Touch " + (string) num_detected);
            float gloaming;
            if (grabbed) {
                llReleaseControls();
                grabbed = FALSE;
                gloaming = 0;
llOwnerSay("Controls released.");
            } else {
                fixCtrl = TRUE;
                llRequestPermissions(llGetOwner(), PERMISSION_TAKE_CONTROLS);
                gloaming = 0.1;
            }
            llSetLinkPrimitiveParamsFast(LINK_THIS,
                [ PRIM_GLOW, ALL_SIDES, gloaming ]);
        }

        //  Attachment to or detachment from an avatar

        attach(key attachedAgent) {
//llOwnerSay("Attach " + (string) attachedAgent);
            if (attachedAgent != NULL_KEY) {
                whoDat = attachedAgent;
                if (commandH == 0) {
                    commandH = llListen(commandChannel, "", NULL_KEY, "");
                    tawk("Listening on /" + (string) commandChannel);
                }
            } else {
                llListenRemove(commandH);
                commandH = 0;
            }
        }

        /*  The run_time_permissions() event is received when we
            are granted permissions for PERMISSION_TAKE_CONTROLS
            or PERMISSION_TRIGGER_ANIMATION.  We then make the
            request we're now permitted to submit.  */

        run_time_permissions(integer perm) {
llOwnerSay("Requesting permissions: " + (string) perm);
            if (perm & PERMISSION_TAKE_CONTROLS) {
                if (fixCtrl) {
                    fixCtrl = FALSE;
                    llTakeControls(CONTROL_UP |
                                   CONTROL_DOWN |
                                   CONTROL_FWD |
                                   CONTROL_BACK |
                                   CONTROL_RIGHT |
                                   CONTROL_LEFT |
                                   CONTROL_ROT_RIGHT |
                                   CONTROL_ROT_LEFT |
                                   CONTROL_ML_LBUTTON, TRUE, TRUE);
                    /*  If we've taken the controls in response to a
                        "Fix controls" command, start a timer to
                        automatically release them after half a second.  */
                    if (cmdperm) {
                        llSetTimerEvent(0.5);
                    } else {
                        grabbed = TRUE;         // Set toggle for touch action
                    }
llOwnerSay("Controls taken.");
                }
            }

            if (perm & PERMISSION_TRIGGER_ANIMATION) {
                if (fixAnim) {
                    fixAnim = FALSE;
                    string an = llGetAnimation(whoDat);
                    string anin = "";
                    if (an == "Sitting") {
                        anin = "sit";
                    } else if (an == "Sitting on Ground") {
                        anin = "sit_ground_constrained";
                    }
                    if (anin != "") {
                        llStopAnimation(anin);
                        llStartAnimation("stand");

                        /*  Changing the animation to "stand" causes the avatar to
                            physically stand, but does not change its state from
                            a sitting state to "Standing".  To do that, we need to
                            perform an llUnSit().  But in an avatar attachment (as
                            opposed to a vehicle on which it's sitting), this only
                            works when the avatar is over land which the attachment's
                            owner owns or to which they have group rights.  This
                            means that in many cases of un-seats over third party
                            land, this  will have no effect, but there's no harm in
                            trying and it may help if you're deposited on your own
                            land or that where you have group rights.  */

                        llUnSit(whoDat);
                    } else {
                        tawk("Unknown animation state: " + an);
                    }
                }

                if (testAnim) {
                    testAnim = FALSE;
                    list al = llGetAnimationList(whoDat);
                    integer i;

                    for (i = 0; i < llGetListLength(al); i++) {
                        string k = llList2String(al, i);
                        if (k != "2408fe9e-df1d-1d7d-f4ff-1384fa7b350f") {
                            tawk("Stopping animation " + k);
                            llStopAnimation(k);
                        }
                    }
                }
            }
        }

        /*  Log control inputs received.  This is purely for testing
            whether we have successfully taken controls.  */

        control(key id, integer level, integer edge) {
llOwnerSay("Control: level " + (string) level + " edge " + (string) edge);
        }

        /*  The listen event handler processes messages from
            our chat control channel.  */

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message, FALSE);
        }

        /*  The timer event is used to release controls a half second
            after we've obtained them via the "Fix controls" command.  */

        timer() {
            cmdperm = FALSE;
            llSetTimerEvent(0);
            llReleaseControls();
            tawk("Controls released.");
        }
    }
