    /*

                    Fourmilab UFO

                    by John Walker

        This script contains support for UFO-specific features, as
        opposed to the generic vehicle facilities implemented in the
        other scripts.

    */

    key owner;
    integer flying = FALSE;             // Are we flying ?

    vector colourMin = <0, 0, 1>;       // Minimum colour
    vector colourMax = <1, 1, 1>;       // Maximum colour

    //  Colours of lights

    list lColours;

    //  Link indices of components we manipulate

    list lLights;                   // Lights 0 - 7

    //  Pilotage messages

    integer LM_PI_PILOT = 27;       // Pilot sit / unsit

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

    /*  hsv_to_rgb  --  Convert HSV colour values stored in a vector
                        (H = x, S = y, V = z) to RGB (R = x, G = y, B = z).
                        The Hue is specified as a number from 0 to 1
                        representing the colour wheel angle from 0 to 360
                        degrees, while saturation and value are given as
                        numbers from 0 to 1.  */

    vector hsv_to_rgb(vector hsv) {
        float h = hsv.x;
        float s = hsv.y;
        float v = hsv.z;

        if (s == 0) {
            return < v, v, v >;             // Grey scale
        }

        if (h >= 1) {
            h = 0;
        }
        h *= 6;
        integer i = (integer) llFloor(h);
        float f = h - i;
        float p = v * (1 - s);
        float q = v * (1 - (s * f));
        float t = v * (1 - (s * (1 - f)));
        if (i == 0) {
            return < v, t, p >;
        } else if (i == 1) {
            return < q, v, p >;
        } else if (i == 2) {
            return < p, v, t >;
        } else if (i == 3) {
            return < p, q, v >;
        } else if (i == 4) {
            return < t, p, v >;
        } else if (i == 5) {
            return < v, p, q >;
        }
        return < 0, 0, 0 >;
    }

    //  chooseColour  --  Choose the next target colour

    vector chooseColour() {
        vector crange = colourMax - colourMin;
        vector colour = colourMin +
                            < crange.x * llFrand(1),
                              crange.y * llFrand(1),
                              crange.z * llFrand(1) >;
        return colour;
    }

    //  aniSpeed  --  Set animation speed

    float aniSpeed() {
        float speed = llVecMag(llGetVel());         // Absolute speed

        float timeri = (10 - speed) / 10;
        if (timeri < 0.25) {
            timeri = 0.25;
        } else if (timeri > 1) {
            timeri = 1;
        }
        return timeri;
    }

    //  setColours  --  Set colours of lights

    setColours() {
        integer i;

        for (i = 0; i < 8; i++) {
            vector col = <0.65, 0.65, 0.65>;
            float glow = 0;
            integer shine = PRIM_SHINY_NONE;
            if (flying) {
                col = llList2Vector(lColours, i);
                float speedfac = llVecMag(llGetVel()) / 10;
                if (speedfac > 1) {
                    speedfac = 1;
                }
                glow = 0.1 * speedfac;
                shine = PRIM_SHINY_MEDIUM;
            }
            llSetLinkPrimitiveParamsFast(llList2Integer(lLights, i),
                [ PRIM_COLOR, ALL_SIDES, col, 1,
                  PRIM_GLOW, ALL_SIDES, glow,
                  PRIM_BUMP_SHINY, ALL_SIDES, shine, PRIM_BUMP_NONE ]);
        }
    }

    default {
        state_entry() {
            owner = llGetOwner();

            integer i;

            lLights = [ ];
            lColours = [ ];
            //  Initialise light link numbers and initial colours
            for (i = 0; i < 8; i++) {
                lLights += findLinkNumber("Light " + (string) i);
                lColours += hsv_to_rgb(chooseColour());
            }
        }

        //  When we're instantiated, reset script

        on_rez(integer num) {
            llResetScript();
        }

        //  Link messages from other scripts

        link_message(integer sender, integer num, string str, key id) {

            //  LM_PI_PILOT (27): Pilot sit / unsit

            if (num == LM_PI_PILOT) {
//llOwnerSay("UFO message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);
                if ((flying = (id != NULL_KEY))) {
                    //  Pilot sits
                    llSetTimerEvent(aniSpeed());
                } else {
                    //  Pilot stands
                    llSetTimerEvent(0);             //  Stop animation timer
                }
                setColours();
            }
        }

        //  Process timer event

        timer() {
            setColours();

            lColours = llList2List(lColours, 1, -1) + hsv_to_rgb(chooseColour());
            llSetTimerEvent(aniSpeed());
        }
    }
