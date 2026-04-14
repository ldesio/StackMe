*! Apr 14'26

capture program drop genstacksO			// 'Opening' program for genstacksP, greatly reducing code executed for each context


program define genstacksO, rclass							// Called by 'stackmeWrapper'; calls subprograms varsImpliedByStubs
															// stunsImpliedByVars and subprogram 'errexit'


*pause on

pause genstO(0)
global errloc "genstacks0"									// Global that keeps track of execution location for benefit of 'errexit'

															

********
capture noisily {											// Open capture braces mark start ot code where errors will be captured
********	


	syntax anything [aw fw pw/], [ USErcontxts(varlist) NOContexts STAckid(name) NOStacks ITEmname(varlist) NOCheck ] ///
								 [ REPlace NODiag KEEpmisstacks FE(namelist) FEPrefix(string) LIMitdiag(integer -1) ] ///
								 [ CTXvar(varname) ORIgdta(string) WTExplst nc(integer 0) c(integer 0) NVArlst(integer 1) *] 

								 
	if `limitdiag' == -1  local limitdiag = .				// If unlimited make that a very large number

	local multivarlst = "`anything'"						// Varlist transmitted on call to this cmd
															// (put into `multivarlst' so legacy code will work)
															// (for 'genstacks' each varlist may be a stublist)
					
		
	capture confirm variable S2stkid						// Check if we already have an S2stkid variable
	if _rc==0  {
		local msg = "This dataset seems to be doubly-stacked (has S2stkid var; will exit on 'ok'"	
*					 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit "`msg' (cannot triple-stack with 'genstacks')"
		exit 1
	}
	
	else  {													// Else dataset is not doubly-stacked
			
	   capture confirm variable SMstkid
	   if _rc==0  {
		  local msg = "This dataset seems to be stacked (has SMstkid variable)"
*				    12345678901234567890123456789012345678901234567890123456789012345678901234567890
		   display as error "`msg'"
		   capture window stopbox rusure "`msg'; genstacks will try to double-stack these data – is that what you want?{txt}"
		   if _rc  {										// Non-zero return code means user did NOT OK this action
			  
			  local filename : char _dta[filename]			// CHECK FILENAME FOR EVIDENCE OF STACKED FILE							***
			  gettoken prfx rest : filename, parse("_")		// If file was already stacked, get prefix preceeding "_"

			  if "`prfx'" != "STKD" & "`prefix'" != "S2KD"  {	
				 local msg = "If data are not stacked, drop all SM.. variables before invoking this command"
			     errexit "`msg'"
			     window stopbox stop "`msg';  will exit on 'OK'"
				 exit 1
			  }
			  else  {
				 local dblystkd = "dblystkd"					// Else set double-stacking flag
				 noisily display "Execution continues with double-stacking this dataset.."
			  }
			   
		   } // endif _rc
		   
	   } //endif _rc
			
	} //endelse confirm var `S2stkid'
	
	
	
pause genstO(1)
global errloc "genstO(1)"									// Global that keeps track of execution location for benefit of 'errexit'

		
		
	
	
										// (1) HERE WE DO THE HEAVY LIFTING, PARSING THE TWO SYNTAXES FOR 'genstacks'
												
												
	local impliedVars = ""									// List of vars accumulated across varlists & stublists
	local reshapeStubs = ""									// List of stubnames collected up across varlists & stublists
	
	local postpipes = "`multivarlst'"						// Pretend what user typed started with "||", now stripped
															// (`multivarlst' is `anything' from the initial 'syntax command)
															
	while "`postpipes'"!=""  {								// While there is anything left of what user typed
	
	   if substr(strtrim("`postpipes'"),1,2)=="||"  local postpipes = substr(strtrim("`postpipes'"),3,.)
	
	   local isStub = 0										// By default, in each namelist we expect a varlist
	   local true = 1										// We will set `isStub' to `true' otherwise
	   
	   local dups = ""										// List of duplicate stubs
	   local isvar = ""										// List of supposed stubs that are actually varnames
	   
	   gettoken prepipes postpipes : postpipes,parse("||")	// Get all up to next "||", if any, or end of commandline

	   
	   
	   if ! strpos("`prepipes'","-")  {						// If `prepipes' has NO hyphen this should be a syntax 2 stublist
		  local nstubs = wordcount("`prepipes'")
		  foreach name  of  local prepipes	{				// Cycle thru names in supposed `prepipes' stublist
			 capture confirm variable `name'				// First, confirm that this is NOT an existing variable
			 if _rc==0  local isvar = "`isvar' `name'"		// If RC returns 0, add to list of `isvar' names
		  } //next name
		  
		  if "`isvar'"!=""& wordcount("`isvar'")<`nstubs' { // Perhaps there are some varnames among the stubs
		  
			 local foundvars = "`prepipes'"					// Put them in `foundvars'
			 dispLine ///
				"Variable(s) already exist with stubname(s): `isvar'; drop them from dataset to be stacked?{txt}" aserr
*                12345678901234567890123456789012345678901234567890123456789012345678901234567890
			 local msg = "drop from dataset to be stacked?"
			 capture window stopbox rusure "Variable(s) already exist with stubname(s) `errlist'; `msg'"
			 if _rc  {										// If user did not OK this request
				window stopbox stop "Will exit on 'OK'"		
				exit 1
			 }
			 foreach `var' of local isvar  {				// Else we have OK to drop these vars
				quietly capture drop `var'					// Include "capture" 'cos stubnames may not name existing variables
				local foundvars = subinstr("`foundvars'","`var'","",1)
			 } //next 'var'									// And remove those dropped vars from `foundvars'
			 noisily display "Dropping offending variable(s), execution continues..."
			 
		  } //endif `isvar'									// Else all expected stubs are actually variables
			
		  local impliedVars = "`impliedVars' `foundvars'"	// So add them to accumulating list of varnames
	   	   
		  if "`isvar'"=="" {								// If none of the names are varnames then these are indeed stubnames
			local isStub = `true'							// (whether got here because of "-" or because of verified varnames)
			local tail = "`prepipes'"						// Now check to ensure stubs are unique; start by putting in `tail'
			while "`tail'"!=""  {							// While tail is not empty
			  gettoken head tail : tail						// Parsing on space between names, move from one stub to next
			  local loh = strlen("`head'")					// Get length of current `head' (which was also `name', above)
			  foreach stub  of  local tail  {				// Cycle thru names remaining in tail of supposed stublist
				local los = strlen("`stub'")				// Get string-length of that name
				if substr("`stub'",1,min(`loh',`los'))==substr("`head'",1,min(`loh',`los'))  local dups = "`dups' `stub'&`head'"
			  } //next `stub'
			} //next while
		  } //endif `isvar'
		  
		  if "`dups'"!=""  {
		  	 local errtxt = "A namelist without '-' should list distinct stubs but following are not distinct"
*					   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			 dispLine "errtxt `dups'"
			 local txt = "Stubname conflict(s) in Syntax 2 stublist;"
		   	 window stopbox stop "`txt' use different '||'-delimited stublist for shorter of each pair displayed"
			 exit 1
		  } //endif											// If we pass this "}", stublist survived 2nd batch of checks
			
		  local reshapeStubs = "`reshapeStubs' `prepipes'"	// So add them to accumulating list of stubnames
*		  ******************
		  varsImpliedByStubs `prepipes'						// Call on program appended to 'wrapper'
		  if "$SMreport"!="" exit 1							// See if error was reported by 'varsImplied..'
*		  ******************
		  local implied = r(keepv)							// Implied by the stubs actually specified by user	
		  local impliedVars = "`impliedVars' `implied'"
		  
		  
	   } //endif !`strpos'									// End of codeblk dealing with non-hyphenated var/stub list			
		  
		  
	   
	   else  {  											// Else `prepipes' has a hyphen; parse on that to look for another
	   
		   gettoken head tail : prepipes, parse("-")		// We know `tail' starts with a "-"; see if there is another "-"
		   
		   local tail = strtrim(substr("`tail'",2,.))		// Trim off the leading "-" in `tail'
		   if strpos("`tail'","-")	{						// If there is another "-" in `tail'
			  errexit "genstacks can only have one hyphenated varlist between each set of pipes ("||")"
*					   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  exit 1
		   }
		   
		   if wordcount("`head'")!=1 | wordcount("`tail'")!=1  {
		   	  errexit "Exactly one varname must preceed and follow '-' in 'genstacks' syntax 1 varlist"
*					   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			  exit 1
		   }
		   
		   local stub = "`head'"							// Look for pre-numeric stub, moving back from end of `head'
		   while real(substr("`stub'",-1,1))<.  {			// While no error when converting last char to real..
			  local stub = substr("`head'",1,strlen("`head'")-1) // Shorten stub by one char and repeat
			  if strlen("`stub'")<2  {						// (unless stub is now less than 2-chars long)
			  	 errexit "Supposed variable `head' should be a stub followed by a numeric suffix"
				 exit 1
			  } //endif
		   } //next real									// If `head' survives above test, check for uniform stubs
		   
		   local errlist = ""								// List of unsuitable varnames generated by 'unab'
		   local nomatch = ""								// List of varnames that do not match the stub of `head'
		   local ls = strlen("`stub'")						// Put length of stub in `ls'
		   local suffx = substr("`head'",`ls'+1,.)			// Remainder of `head' is the numeric suffix
		   
		   unab varlist : `prepipes'						// See what Stata makes of the hyphenated varlist
		   local rc = _rc
		   foreach var  in  `varlist'  {					// Check on whatever 'unab' made of each `var'
			  if `rc'  {									// If 'unab' returned a non-zero error code, see why
				 capture confirm variable `var'				// First see if what was returned is a valid varname
				 if _rc  local errlist = "`errlist' `var'"	// Accumulate list of unsuitable var(name)s
			  } //endif `rc'
			   
			  local varst = substr("`var'",1,`ls')			// Get same length stub for each variable
			  if real(substr("`var'",`ls',1))<. | real(substr("`var'",`ls'+1,1))>=.  {	
				 local errlist = "`errlist' `var'"			// If stub ends with # or suffx is not # add to `errlst'
			  }
			  if "`varst'"!="`stub'"  local nomatch = "`nomatch' `var'"
															// If `stub' does not match stub of `head' add to `nomatch'
		   }	//next `var'
			   		   
		   if "`errlist'"!=""  {							// If there were unacceptable names in `prepipes'
			  dispLine "Expected name(s) are not varnames: `errlist'"
			  local rmsg = r(msg)
			  errexit, msg("rmsg")
			  exit 1
		   } //endif `errlst'
			
		   if "`nomatch'"!=""  {
			  local msg = "Variables included in varlist sequence include some with different stubs: `nomatch'"
			  dispLine "`msg'; drop these?"			
			  local rmsg = r(msg)
			  capture window stopbox rusure "`rmsg'"
			  if _rc  {
			   	 window stopbox stop "Lacking permission to drop those vars, will exit on 'OK'"
				 exit 1
			  }
			  foreach var  of  local nomatch  {
				 capture drop `var'							// Use capture in case some are not vars
				 local varlist = stritrim(subinstr("`varlist'","`var'","",1))
			  }												// remove each `var' in `nomatch' from `varlist'
		   } //endif `nomatch'								// (and trim away the redundant space remaining)
		   

		   ******************								// Still need list of stubs implied by above vars
		   stubsImpliedByVars `varlist'						// Program (appended) generates list of stubnames
		   if "$SMreport"!="" exit 1						// See if error was reported by cmd above
*		   ******************
		   local stublist = r(stubs)						// (one stubname per varlist in genstacks syntax 1)
		   
		   if "`stublist'"=="."  local stublist = ""		// If just one "." in stiblist, make it empty
		   local reshapeStubs = "`reshapeStubs' `stublist'" // Accumulate stubs found over all varlists
			 
		   ******************
		   varsImpliedByStubs `stublist'					// See if both varlists have same vars (in any order)
		   if "$SMreport"!="" exit 1						// Break error if error was reported by 'varsImplied..'
		   ******************			
		   local keepvars = r(keepv)						// 'Implied' by the variables actually specified by user
		   local impliedVars = "`impliedVars' `keepvars'"	// Accumulate vars found over all varlists

		   if "`impliedVars'"==""  {
			  errexit "Program error in `genstacks0'"
			  exit 1
		   }

	   } //endelse !`strpos'
	   				   
	} //next pipes
	
	
	
	
	
pause genstO(2)
global errloc "genstO(2)"									// Global that keeps track of execution location for benefit of 'errexit'

		
		
	

															// NOW SEE IF STUBLIST MATCHES VARLIST
	local same : list reshapeStubs === impliedVars			// returns 1 in 'same' if 'implied..'&'keep' have same contents 
*		
	if ! `same'  {
				
		dispLine "Variables in dataset don't match vars implied by varlist: `vars'; Use existing vars?{txt}" aserr
*                 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		local msg = "Variables in dataset are not an exact match for vars implied by varlist(s) – "
		capture window stopbox rusure "`msg'maybe some contexts have fewer variables; use vars that do exist?"
		if _rc   {											// Exit with error if user says "no" 
			errexit "`Absent permission to use existing vars"
			exit 1											// If msg contains "permission" 'errexit' adds "will exit.."
		}
				
		noi display "Execution continues ..."
		local warnmatch = "warned"
		 
		local stublist = "`reshapeStubs'"
		if strpos("`stublist'",".")  local stublist = subinstr("`stublist'", ".", "", .) // Strip missing indicators
															// Eliminate any missing variable indicators from `stublist'
		local reshapeStubs = "`stublist'" 					// (so they end up in 'reshape..' either way)
														
	} //endif !`same'	
	

	
	
pause genst(3)
global errloc "genstO(3)"									// Global that keeps track of execution location for benefit of 'errexit'

		
		
		
										// kHERE WE CHECK ON OPTIONS THAT ARE PROBLEMATIC ON 'genstacks' COMMANDS
										
	if "`usercontxts'"!="" | "`nocontexts'"!=""  {		// If either of these were optioned by user..
		errexit "In V2, contextvars are set by {help SMutilities} and cannot be overriden in genstacks"
*				 12345678901234567890123456789012345678901234567890123456789012345678901234567890abcdefg
		exit 1
	}
		
	if "`stackid'"!="" | "`nostacks'"!=""  {
		display as err "In Version 2, the stack ID variable is named SMstkid and is not user-optioned"
*						 	12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox rusure "In Version 2, the stack ID variable is named SMstkid and is not user-optioned; continue?"
		if _rc  {
			errexit "Lacking permission to continue"
			exit 1
		}
	}	
		
	if "`itemname'"!=""  {								// In genstacks any 'itemname' option names var to be kept, below
		capture confirm variable `itemname'				// (it provides a link from each stack to other battery items)
		if _rc  {
			errexit "Option `itemname' does not name an existing variable" // 'errexit' limited to 60 chars
*						12345678901234567890123456789012345678901234567890123456789012345678901234567890
			exit 1
		}												// 'itemname' will override SMitemname dataset characteristic
		else {											// (created by genstacks)
			if `limitdiag'  noisily display "NOTE: optioned itemname will override dataset characteristic set by 'genstacks'"
*               		  		                12345678901234567890123456789012345678901234567890123456789012345678901234567890
		} //endelse
			
	} //endif `itemname'								// Vars in 'varsImpliedByStubs' need to be kept in working data
														// (no SM.. variables in unstacked data)
															
	local impliedVars = "`impliedVars' `itemname'"		// (genstacks does need SMitem, provided in wrapper codeblk (6)										
			   
	scalar GENSTKVARS = "`impliedVars'"					// Put into scalar accessible to other subprograms
		
													
											
					
											
pause genstO(3)		
global errloc "genstO(3)"									// Global that keeps track of execution location for benefit of 'errexit'

										// For genstacks, additional vars are generally needed beyond those in `multivarlst'
										// Also need to see if genstacks is to double-stack the data or just singly stack.
										// Either way appropriate variables need to be created and flagged for keeping
															
		
	if "`nostacks'"!="" {
		display as error "'nostacks' cannot be optioned with command genstacks. Ignore and continue?{txt}"
		capture window stopbox rusure "'nostacks' cannot be optioned with command genstacks. Ignore and continue?"
*						 	                12345678901234567890123456789012345678901234567890123456789012345678901234567890	
		if _rc {
			errexit "Lacking permission to ignore the 'nostacks' option"
			exit 1
		}												//  (no need to restore full dataset since not yet messed with)
		noi display "Execution continues ..."
		local nostacks = ""
	}													// This should never happen

		
	else  {												// Else there is no SMstkid variable

		capture confirm variable SMunit					// SHOULD WE ALSO CHECK FOR HANGING SMnstks?							***
		if _rc==0  {
			display as error "NOTE: Variable SMunit should not already exist in unstacked data; continue anyway?{txt}"
			capture window stopbox rusure "Variable SMunit should not already exist in unstacked data; Continue anyway?"
*						                       12345678901234567890123456789012345678901234567890123456789012345678901234567890
			if _rc!=0  {
				errexit "Variable SMunit should not already exist in unstacked data"
				exit 1
			}
				foreach var in SMunit SMnstks SMmxstks SMitem SMunit  {
				capture drop `var'
			}
			noisily display "SMunit and any other 'SM' variables will be replaced as execution continues ...{txt}"
*						     12345678901234567890123456789012345678901234567890123456789012345678901234567890
		} //endif _rc 									// Will need these vars for stacking ** ONLY IN WORKING DTA				***
			
	} //endelse
			
	global dblystkd = ""								// Global used in `cmd'P must be empty if not double-stacked
	local dblystkd = ""

		
	if "$dblystkd"!=""  {								// If data are to be double-stacked (SMstkid already exists)
											
		capture confirm variable S2stkid				// S2stkid should not already exist in unstacked data
			
		if _rc == 0  {
			display as error "Variable S2stkid should not already exist in data to be double-stackd. Continue?{txt}"
			capture window stopbox rusure "Variable S2unit should not already exist in data not double-stacked. Continue anyway?"
*						 	  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
			if _rc!=0  {
				errexit "Variable S2unit should not already exist in data not double-stacked"
				exit
			}
			else  {
				foreach name in S2stkid S2nstks S2mxstks S2unit S2item {
				   capture drop `name'					// Drop these vars if they exist
				}
				noisily display "S2stkid and any other 'S2' variables will be replaced as execution continues ..."
			} //endelse
		} //endif _rc==0								// WILL NEED THESE VARS FOR STACKING  ** ONLY IN WORKING DTA			***

	} //endif $dblystkd'
		
		
	global dblystkd = "`dblystkd'"						// Make copy in global accessible from elsewhere
		
															// Here initialize SMvars, where they will not be kept if $exit
	if "$dblystkd"==""  {
			
		qui gen SMstkid = .								// Missing obs will be filled with values generated by reshape
		gen SMunit = _n									// Above missing-filled vars created to avoid re-ordering
			
	}
		
	if "`dblystkd'"!=""  {
			
		qui gen S2stkid = .								// Missing obs will be filled with values generated by reshape
		gen S2unit = _n									// Above missing-filled vars created to avoid re-ordering
		label var S2unit "Sequential ID for observations that were units of analysis in singly-stackd data"
*						      12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}

		
	local impliedVars `impliedVars' SMstkid SMunit 		// Add S2 versions if doubly-stacked
	if "`dblystkd'"!=""  local impliedVars `impliedVars' S2stkid S2unit
	return local impliedVars `impliedVars'
	return local reshapeStubs `reshapeStubs'			// So-called because stubs are used for reshaping in 'genstacksP'
		
 
	local skipcapture = "skip"								// Local, if set, prevents capture code, below, from executing

	
* *************
capture  } //end capture									// Endbrace for code in which errors are captured
* *************												// Any such error would cause execution to skip to here
															// (failing to trigger the 'skipcapture' flag two lines up)


if "`skipcapture'"==""  {									// If not empty we did not get here due to stata error
	
	if _rc  {
		errexit "Stata reports program error in $errloc"
		exit
	}
}

exit														// Cluge avoides "matching close braces" error on error exit



		
end genstacksO



********************************************** END OF PROGRAM *************************************************************************
