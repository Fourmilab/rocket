   /*

             Fourmilab Script Processor

                    by John Walker

    */

    integer LM_SP_INIT = 50;        // Initialise
    integer LM_SP_RESET = 51;       // Reset script
    integer LM_SP_STAT = 52;        // Print status
    integer LM_SP_RUN = 53;         // Add script to queue
    integer LM_SP_GET = 54;         // Request next line from script
    integer LM_SP_INPUT = 55;       // Input line from script
    integer LM_SP_EOF = 56;         // Script input at end of file
    integer LM_SP_READY = 57;       // New script ready
    integer LM_SP_ERROR = 58;       // Requested operation failed

    //  Pilotage messages
    integer LM_PI_PILOT = 27;       // Pilot sit / unsit

    //  Trace messages
    integer LM_TR_SETTINGS = 120;   // Broadcast trace settings
    //  Trace module selectors
    integer LM_TR_S_SCR = 16;       // Script Processor

    string ncSource = "";           // Current notecard being read
    key ncQuery;                    // Handle for notecard query
    integer ncLine = 0;             // Current line in notecard
    integer ncBusy = FALSE;         // Are we reading a notecard ?
    list ncQueue = [ ];             // Stack of pending notecards to read
    list ncQline = [ ];             // Stack of pending notecard positions
    list ncLoops = [ ];             // Loop stack

    key whoDat;                     // User (UUID) who requested script

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

    ttawk(integer level, string msg) {
        if (trace >= level) {
            tawk(msg);
        }
    }

    //  abbrP  --  Test if string matches abbreviation

    integer abbrP(string str, string abbr) {
        return abbr == llGetSubString(str, 0, llStringLength(abbr) - 1);
    }
    
    //  processScriptCommand  --  Handle commands local to script processor
    
    integer processScriptCommand(string message) {
        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments
        integer argn = llGetListLength(args);

//llOwnerSay("processScriptCommand " + llList2CSV(args));    
        if ((argn >= 3) &&
            abbrP(llList2String(args, 0), "se") &&
            abbrP(llList2String(args, 1), "sc")) {
            
            string command = llList2String(args, 2);
            
            //  Set script loop [n]         -- Loop n times (default infinite)
        
            if (abbrP(command, "lo")) {
                integer iters = -1;
                
                if (argn >= 4) {
                    iters = llList2Integer(args, 3);
                }
                ncLoops = [ iters, ncLine ] + ncLoops;
//llOwnerSay("Start loop " + llList2CSV(ncLoops));

            //  Set script end              -- End loop
            
            } else if (abbrP(command, "en")) {
//llOwnerSay("End loop " + llList2CSV(ncLoops));
                integer iters = llList2Integer(ncLoops, 0);
                
                if ((iters > 1) || (iters < 0)) {
                    //  Make another iteration
                    if (iters > 1) {
                        iters--;
                    }
                    //  Update iteration count in loop stack
                    ncLoops = llListReplaceList(ncLoops, [ iters ], 0, 0);
                    //  Set line counter to line after loop statement
                    ncLine = llList2Integer(ncLoops, 1);
                } else {
                    /*  Final iteration: continue after end statement,
                        pop loop stack.  */
                    ncLoops = llDeleteSubList(ncLoops, 0, 1);
                }
            }
            return 1;
        }
        return 0;
    }

    //  processNotecardCommands  --  Read and execute commands from a notecard

    processNotecardCommands(string ncname, key id) {
        if (llGetInventoryKey(ncname) == NULL_KEY) {
            llMessageLinked(LINK_THIS, LM_SP_ERROR, "No notecard named " + ncname, id);
            return;
        }
        if (ncBusy) {
            ncQueue = [ ncSource ] + ncQueue;
            ncQline = [ ncLine ] + ncQline;
            ttawk(1, "Pushing script: " + ncSource + " at line " + (string) ncLine);
            ncSource = ncname;
            ncLine = 0;
        } else {
            ncSource = ncname;
            ncLine = 0;
            ncBusy = TRUE;                  // Mark busy reading notecard
            llMessageLinked(LINK_THIS, LM_SP_READY, ncSource, id);
            ttawk(1, "Begin script: " + ncSource);
        }
    }

    default {

        on_rez(integer start_param) {
            llResetScript();
        }

        state_entry() {
            owner = llGetOwner();
            ncBusy = FALSE;                 // Mark no notecard being read
            ncQueue = [ ];                  // Queue of pending notecards
            ncQline = [ ];                  // Clear queue of return line numbers
            ncLoops = [ ];                  // Clear queue of loops
        }

        /*  The link_message() event receives commands from the client
            script and passes them on to the script processing functions
            within this script.  */

        link_message(integer sender, integer num, string str, key id) {
//ttawk("Script processor link message sender " + (string) sender + "  num " + (string) num + "  str " + str + "  id " + (string) id);

            //  LM_SP_INIT (50): Initialise script processor

            if (num == LM_SP_INIT) {
                if (ncBusy && trace) {
                    string nq = "";
                    if (llGetListLength(ncQueue) > 0) {
                        nq = " and outer scripts: " + llList2CSV(ncQueue);
                    }
                    ttawk(1, "Terminating script: " + ncSource + nq);
                }
                ncSource = "";                  // No current notecard
                ncBusy = FALSE;                 // Mark no notecard being read
                ncQueue = [ ];                  // Queue of pending notecards
                ncQline = [ ];                  // Clear queue of return line numbers
                ncLoops = [ ];                  // Clear queue of loops

            //  LM_SP_RESET (51): Reset script

            } else if (num == LM_SP_RESET) {
                llResetScript();

            //  LM_SP_STAT (52): Report status

            } else if (num == LM_SP_STAT) {
                string stat = "Script processor:  Busy: " + (string) ncBusy;
                if (ncBusy) {
                    stat += "  Source: " + ncSource + "  Line: " + (string) ncLine +
                            "  Queue: " + llList2CSV(ncQueue) +
                            "  Loops: " + llList2CSV(ncLoops);
                }
                stat += "\n";
                integer mFree = llGetFreeMemory();
                integer mUsed = llGetUsedMemory();
                stat += "    Script memory.  Free: " + (string) mFree +
                        "  Used: " + (string) mUsed + " (" +
                        (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)";

                llRegionSayTo(id, PUBLIC_CHANNEL, stat);

            //  LM_SP_RUN (53): Run script

            } else if (num == LM_SP_RUN) {
                if (!ncBusy) {
                    whoDat = id;                     // User who started script
                }
                processNotecardCommands(str, id);

            //  LM_SP_GET (54): Get next line from script

            } else if (num == LM_SP_GET) {
                if (ncBusy) {
                    ncQuery = llGetNotecardLine(ncSource, ncLine);
                    ncLine++;
                }

            //  LM_PI_PILOT (27): Set pilot agent key

            } else if (num == LM_PI_PILOT) {
                agent = id;

            //  LM_TR_SETTINGS (120): Set trace modes

            } else if (num == LM_TR_SETTINGS) {
                trace = (llList2Integer(llJson2List(str), 0) & LM_TR_S_SCR) != 0;

            }
        }

        //  The dataserver event receives lines from the notecard we're reading

        dataserver(key query_id, string data) {
            if (query_id == ncQuery) {
                if (data == EOF) {
                    ttawk(1, "End script: " + ncSource);
                    if (llGetListLength(ncQueue) > 0) {
                        //  This script is done.  Pop to outer script.
                        ncSource = llList2String(ncQueue, 0);
                        ncQueue = llDeleteSubList(ncQueue, 0, 0);
                        ncLine = llList2Integer(ncQline, 0);
                        ncQline = llDeleteSubList(ncQline, 0, 0);
                        ttawk(5, "Pop to " + ncSource + " line " + (string) ncLine);
                        ncQuery = llGetNotecardLine(ncSource, ncLine);
                        ncLine++;
                    } else {
                        //  Finished top level script.  We're done/
                        ncBusy = FALSE;         // Mark notecard input idle
                        ncSource = "";
                        ncLine = 0;
                        ttawk(5, "Hard EOF: all scripts complete");
                        llMessageLinked(LINK_THIS, LM_SP_EOF, "", whoDat);
                    }
                } else {
                    string s = llStringTrim(data, STRING_TRIM);
                    //  Ignore comments and send valid commands to client
                    if ((llStringLength(s) > 0) && (llGetSubString(s, 0, 0) != "#")) {
                        if (processScriptCommand(s) != 0) {
                            //  Fetch next line from script
                            ncQuery = llGetNotecardLine(ncSource, ncLine);
                            ncLine++;
                        } else {
                            llMessageLinked(LINK_THIS, LM_SP_INPUT, s, whoDat);
                        }
                    } else {
                        /*  The process of aborting a script due to an error
                            in the script or other exogenous event is asynchronous
                            to the completion of a pending llGetNotecardLine()
                            request.  That means that it's possible we may get
                            here, receiving data for a script which has been
                            terminated while the request was pending.  If that's
                            the case ncBusy will be FALSE and we don't want to
                            request the next line, which will fail because
                            ncSource will have been cleared.  */
                        if (ncBusy) {
                            //  It was a comment or blank line; fetch the next
                            ncQuery = llGetNotecardLine(ncSource, ncLine);
                            ncLine++;
                        }
                    }
                }
            }
        }
    }
