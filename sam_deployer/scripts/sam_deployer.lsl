    /*
                   SAM Site Deployer

                    by John Walker
    */

    key owner;                          //  Owner UUID
    string ownerName;                   //  Name of owner

    integer commandChannel = 75;        // Command channel in chat (S-75 Dvina, SA-2 Guideline)
    integer commandH;                   // Handle for command channel
    key whoDat = NULL_KEY;              // Avatar who sent command
    integer restrictAccess = 2;         // Access restriction: 0 none, 1 group, 2 owner
    integer echo = TRUE;                // Echo chat and script commands ?

    float REGION_SIZE = 256;            // Size of regions

    integer siteChannel = -982449720;   // Channel for communicating with sites
    string ypres = "Q?+:$$";            // It's pronounced "Wipers"

    integer siteIndex = 0;              // Index of last site deployed

    //  gRand  -- Generate Gaussian random deviate with zero mean, unit variance

    integer gRiset = FALSE;
    float gRfset;

    float gRand() {
        float v1;
        float v2;
        float rsq;

        if (!gRiset) {
            do {
                v1 = llFrand(2) - 1;
                v2 = llFrand(2) - 1;
                rsq = (v1 * v1) + (v2 * v2);
            } while ((rsq >= 1) || (rsq == 0));
            float fac = llSqrt(-2 * (llLog(rsq) / rsq));
            gRfset = v1 * fac;
            gRiset = TRUE;
            return v2 * fac;
        } else {
            gRiset = FALSE;
            return gRfset;
        }
    }

    //  igRand  --  Generate inverse Gaussian random deviate

    float igRand(float mu, float lambda) {
        float v = gRand();
        float y = v * v;
        float x = mu + ((mu * mu * y) / (2 * lambda)) -
            ((mu / (2 * lambda)) * llSqrt((4 * mu * lambda * y) + (mu * mu * y * y)));
        float test = llFrand(1);
        if (test <= (mu / (mu + x))) {
            return x;
        }
        return (mu * mu) / x;
    }

    //  rSign  --  Return a random sign, 1 or -1

    integer rSign() {
        if (llFrand(1) <= 0.5) {
            return -1;
        }
        return 1;
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

    //  arg  --  Extract an argument with a default

    string arg(list args, integer argn, integer narg, string def) {
        if (narg < argn) {
            return llList2String(args, narg);
        }
        return def;
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

        //  Deploy                      Deploy sites

        } else if (abbrP(command, "de")) {
            if (argn < 2) {
                tawk("Usage: deploy n_sites radius t_rad t_alt height uniform/gaussian/igauss");
            } else {
                integer nsites = (integer) arg(args, argn, 1, "1");
                float radius = (float) arg(args, argn, 2, "10");
                float t_rad = (float) arg(args, argn, 3, "0.1");
                float t_alt = (float) arg(args, argn, 4, "99");
                float height = (float) arg(args, argn, 5, "50");
                string randr = arg(args, argn, 6, "uniform");

                integer bogus = FALSE;
                if ((radius <= 0) || (radius >= 256)) {
                    tawk("Invalid radius: must be 0 < radius < 256");
                    bogus = TRUE;
                }
                if ((t_rad <= 0) || (t_rad > 99.9)) {
                    tawk("Invalid threat radius: must be 0 < t_rad < 99.9");
                    bogus = TRUE;
                }
                if ((t_alt <= 0) && (t_alt > 99)) {
                    tawk("Invalid threat altitude: must be 0 < t_alt <= 99");
                    bogus = TRUE;
                }
                if ((height <= 0) || (height > 99)) {
                    tawk("Invalid displayed height: must be 0 < height <= 99");
                    bogus = TRUE;
                }
                if (!(abbrP(randr, "u") || abbrP(randr, "g") || abbrP(randr, "i"))) {
                    tawk("Invalid random distribution: must be uniform/gaussian/igauss");
                    bogus = TRUE;
                }

                if (!bogus) {
                    integer i;

                    for (i = 0; i < nsites; i++) {
                        siteIndex++;
                        placeSite(siteIndex, radius, t_rad, t_alt, height, randr);
                    }
                    if (siteIndex > 16) {
                        tawk("Warning: \"Set SAM scan\" cannot detect more than 16 SAM sites.");
                    }
                }
            }

        //  Remove                      Remove all sites

        } else if (abbrP(command, "re")) {
            llRegionSay(siteChannel, ypres);
            siteIndex = 0;

        } else {
            tawk("Huh?  \"" + message + "\" undefined.  Chat /" +
                (string) commandChannel + " help for the User Guide.");
            return FALSE;
        }
        return TRUE;
    }

    //  placeSite  --  Place a SAM site within the radius

    placeSite(integer siteno, float radius, float siterad, float sitealt, float height, string randr) {

        vector pos = llGetPos();
        vector where = <-1, -1, 0>;

        /*  Generate a random position within radius of our
            position, rejecting any which fall outside the region.  */

        while ((where.x < 0) || (where.x >= REGION_SIZE) ||
               (where.y < 0) || (where.y >= REGION_SIZE)) {
            float posx;
            float posy;

            if (abbrP(randr, "u")) {
                posx =  llFrand(radius * 2) - radius;
                posy = llFrand(radius * 2) - radius;
            } else if (abbrP(randr, "g")) {
                posx = radius * gRand() * 0.5;
                posy = radius * gRand() * 0.5;
            } else if (abbrP(randr, "i")) {
                posx = radius * igRand(1, 1) * rSign();
                posy = radius * igRand(1, 1) * rSign();
            }
            where = pos + < posx, posy, height / 2 >;
        }

        /*  The start_param is encoded as follows:
                NNRRRAAHH

                NN      Site number (1 - 99)
                RRR     Threat radius, units of 0.1 metres
                AA      Threat altitude, metres
                HH      Height of displayed barrier, metres
        */

        integer sparam = (siteno * 10000000) +
            (((integer) llRound(siterad * 10)) * 10000) +
            (((integer) llRound(sitealt)) * 100) +
            ((integer) llRound(height));

        /*  Now place the site.  Since we can't llRezObject more
            than ten metres from our current location, jump to
            the rez location, create the site, then jump back to
            our original position.  */

llOwnerSay("Place " + (string) siteno + " at " + (string) where + " sparam " + (string) sparam);
        llSetRegionPos(where);
        llRezObject("SAM site", where, ZERO_VECTOR, ZERO_ROTATION, sparam);
        llSetRegionPos(pos);
    }

    default {

        state_entry() {
            owner = llGetOwner();
            ownerName =  llKey2Name(owner);  //  Save name of owner

            siteIndex = 0;

            //  Start listening on the command chat channel
            commandH = llListen(commandChannel, "", NULL_KEY, "");
            llOwnerSay("Listening on /" + (string) commandChannel);
        }

        /*  The listen event handler processes messages from
            our chat control channel.  */

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message, FALSE);
        }

    }
