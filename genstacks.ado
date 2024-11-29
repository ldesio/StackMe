
capture program drop genstacks			// Alias 'genst' which exists as a separate program defined after this one

program define genstacks

*!  Stata version 9.0; stackMe version 2, updated May'23 from major re-write in June'22; again in May'04 to include post-wrapper code

	version 9.0
										// Here set stackMe command-specific options and call the stackMe wrapper program  
										// (lines that end with "**" need to be tailored to specific stackMe commands)
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'
															
	local optMask = " ITEmname(varname) CONtextvars(varlist) TOTstackname(name) FE(namelist) FEPrefix(string) " ///					**
				  + "LIMitdiag(integer -1) KEEpmisstacks NOCheck"												//					**
															// NOTE that, for this `cmd', stackid is a local not a variable			**
															// NOTE that, for this `cmd', first option is not also a prefix			**
															// and does not have a negative counterpart
															
	
	local prfxtyp = /*"var" "othr"*/"none"					// Nature of varlist prefix – var(list) or other. (`stubname' will		**
															// be referred to as `opt1', the first word of `optMask', in codeblock 
															// (0) of stackmeWrapper called just below). `opt1' is always the name 
															// of an option that holds a varname or varlist (which must be referred
															// using double-quotes). Normally the variable named in `opt1' can be 
															// updated by the prefix to a varlist. In geniimpute the prefix can 
															// itself be a varlist.
		
		
	local multicntxt = "multicntxt"							// Whether `cmd'P takes advantage of multi-context processing			**
															// (revised genstacks DOES do so; wrapper equivalent is `noMultiContxt')
		
	local save0 = "`0'"										// Seems necessary, perhaps because called from gendi
										
										

*	************************
	stackmeWrapper genstacks `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line				
*	************************								// (`0' is what user typed; `prfxtyp' & `optMask' were set above)	
															// (`prfxtyp' placed for convenience; will be moved to follow optns)
															// () that happens on fifth line of stackmeCaller's codeblock 0)
															
*  Standard stackMe options:
*  EXTradiag REPlace NEWoptions MODoptions NEWexpression MODexpression NODIAg NOCONtexts NOSTAcks  
*  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS. All of these except limitdiag are added in stackmeWrapper, codeblk(2)

	
	if $exit  exit 1										// Any error return overrides following codeblocks
	


								// On return from wrapper ...
								
	
								
	local 0 = "`save0'"										// Restore what the user typed
	

*	************
	syntax anything ,  [ LIMitdiag(integer -1) NODiag REPlace ] *									
*	************	
	
	
										
										// Next code blocks post-process new variables created in genstacksP
										
	
		
	if `limitdiag'==0 noisily display " "					// No 'continue' for final busy dot

	
	
	
	
										// (2) Make labels for reshaped vars, based on first var in each battery ...
										
										
										
	local namelist = "$multivarlst"						// Global saved in codeblock (5) of stackmeWrapper
	
	local varlabel = ""									// Initialize a local outside foreach loop to hold eventual label
	
	local response = 0									// Local at top level to register responses within if or foreach
		
	foreach stub of local namelist {					// (whether specified in syntax 2 or derived from syntax 1 varlist)
	
		foreach var of varlist `stub'*  {				// Sleight-of-hand to get first var in each battery
		
			local varname = "`var'"						// Need to save copy for use outside this loop
			
			local label : variable label `var'			// Label stub, will be extended as appropriate
			
			if "`label'"=="" {							// If this var has no label, provide dummy label
			   local varlabel = "Stkd `varname'"		// Use varname for 
			   continue, break							// Break out of varlist loop because have label for stub
			}

			local loc = strpos("`label'", "==")			// Otherwise see if the label contains the string "=="														// (meaning it starts with the associated varname)
			if `loc'>0  {								// If it contains the varname, delete it
				
				local varname = substr("`label'", 1, `loc'-1)

				capture confirm variable `varname'		// See if dummies kept original varname as stubnames			
				if _rc == 0  {							// If this stub was previously a variable ...
					local label : variable label `varname'
					local varlabel = "Stkd `label'"
					continue, break						// Break out of foreach `var' because we found a generic label					
				}										// (from variable whose categories became dummy variables)

				else  {									// Either never labeled or was renamed during gendummies

					local varlabel : variable label `var'
														// Repeat until labels for all dummies have been appended
				} //end else
				
			} //endif 'loc'	
			
			else {											 // Not a gendummies-built battery
			
				if strpos("`label'", "`var'") > 0	{		 // If it has an embedded varname ...
					local loc = strpos("`label'", "`var'")
					local label = substr("`label'",`loc'+strlen("`var'"), .)
					local cc = (substr("`label'", 1, 1))
					mata:st_numscalar("a",ascii("`cc'")) 	 // Get MATA to tell us the ascii value of `cc'

					while (strpos("<=>?@[\/]_{|}~", "`cc'") < 1) & ("`cc'" != "") & ( (a<45 & a!=41) | a>126 )  {
					   local label = substr("`label'", 2, .) // (strpos & 41 are good; a<45 & a>126 are not)
					   local cc =(substr("`label'"),1,1) 	 // Trim chars other than "good" above from front of label
					   mata: st_numscalar("a", ascii("`cc'"))
					}										 // (the above doesnt include " " so leading spaces get trimmed)
					local varlabel = "Stkd " + strltrim("`label'")
					continue, break							 // Break out of foreach 'var' because 1st var is all we need
				}
				else  {
					local varlabel ="Stkd " + strltrim("`label'") // Otherwise use label of first var, unmodified
					continue, break
				}
			} //end else
						
		} //next `var'										// Actually, not so. Will break out of loop after 1st var
		
	
		if `limitdiag' != 0  noisily display "Labeling {result:`stub'}: {result:`varlabel'}"

		quietly label var `stub' "`varlabel'"
	
	} //next `stub'											// Find next now-reshaped var needing a label
	 

	 
	 
	 
		  
		  
									// (3) Drop unstackd versns of now stackd vars if 'replace' optiond; process any `itemname'
									
									
	if "`replace'"=="replace" {								// If  commandline contains option "replace" (or allowed abbreviation)
		varsImpliedByStubs `namelist'						// Program can be found at end of `stackmeWrapper' adofile
		local varlist = r(keepv)

		if `limitdiag'  noisily display _newline "As 'replace' was optioned, dropping original versions of now stacked variables"
*								                  12345678901234567890123456789012345678901234567890123456789012345678901234567890

		drop `varlist'										// 'varlist' is list of variables corresponding to syntax 2 stubs
	}														// (in syntax 1 for genstacks these would have identified each batery)

	
	
	if "`itemname'"!=""  {									// Was there an optioned itemname (name of var pointed to be SMitem)
	  local S_ = "SMitem"
	  if "$dblystkd"!="" local S_ = "S2item"				// These substitutions may be made in 2 locations below
	  local M_ = "SMstkid"
	  if "$dblystkd"!="" local M_ = "S2stkid"				// These substitutions may be made in 2 locations below
	  
	  local act = 0											// By default take no action
	  
	  if "$dblystkd"==""  {									// If data have NOT been doubly-stacked (just 1st stage stacking)
	  	local SMitem : char _dta[SMitem]					// Retrieve name of var stored in SMitem, if any
	    if "`SMitem'"!=""  local act = 1					// If already have itemname for first stage stacks ...
	  }
	  else  {												// Data ARE doubly-stacked ...
	  	local S2item : char _dta[S2item]
	    if "`S2item'"!=""  local act = 2					// If already have itemname for second stage stacks ...
	  }
		
	  if `act'  {
		display as error "Replace existing S_'?"
		if `act'==1 capture window stopbox rusure "Replace existing SMitem? (You can employ a linkage var without declaring it){txt}"
*                                                  12345678901234567890123456789012345678901234567890123456789012345678901234567
		
		if `act'==2 capture window stopbox rusure "Replace existing S2item? (You can employ a linkage var without declaring it){txt}"
		
		if _rc  {
		  window stopbox stop "Ending execution"
		}
		
	    if `act'==1  char define _dta[SMitem] "`itemname'"	// Put "`itemname'" variable name as string into SMitem _dta char
		if `act'==2  char define _dta[S2item] "`itemname'"	// Put "`itemname'" variable name as string into S2item _dta char
		
	  } //endif `act' 									// Emerge from 'if' only if no existing SMitem or if can replace
	  	  
	  if `limitdiag' {										// If diagnostics are being displayed . . .
		local msg = substr("NOTE: Option itemname puts battery ID's varname '`itemname'' in _dta note `S_'",1,80)
		noisily display  "`msg'"							// Display 1st 80 chars of warning message
*                          12345678901234567890123456789012345678901234567890123456789012345678901234567890
		noisily display   "      as an alternative to `M_' for identifying battery items in each stack"
	  }
	} //endif 'itemname'
	  
	else  {													// Else `itemname' was not optioned ...	
	  if `limitdiag' {
		if "`SMitem'"=="" noisily display "NOTE: With no 'itemname' option, battery items are identfied only by var `M_{txt}"
	  }
	} //endelse
	
	

								
								
									// (4) Tidy & rename stackMe vars if optioned ...
									

	if "$dblystkd"==""  {									// If this dataset has just been stacked for first time
	   label var SMstkid "Sequential ID of stacks that were battery items in the unstacked data"
	   tempvar SMnstks
	   egen `SMnstks' = max(SMstkid), by(SMunit)			// Tidy the SM variables created while stacking
	   qui replace SMnstks = `SMnstks'
	   label var SMnstks "Maximum number of stacks for any context in the single-stacked data"
	   drop `SMnstks'										// for some reason I get an error when I order these separately
	}
	
	else {													// If this dataset has just been doubly-stacked
	   label var S2stkid "Sequential ID of secondary stacks in the double-stacked data"
	   tempvar S2nstks
	   egen `S2nstks' = max(S2stkid), by(S2unit)
	   qui replace S2nstks = `S2nstks'
	   label var S2nstks "Maximum number of secondary stacks for any context in the double-stacked data"
	   drop `S2nstks'  // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}															  
	  	   
	   
	local report = "Not saved."								  // Default is to save nothing
	
	if "$dblystkd"==""  {
	   noi display as error _newline "Save stacked data under a new name to avoid overwriting the unstacked file?{txt}"															
	   capture window stopbox rusure "Save stacked data under a new name to avoid over-writing the unstacked file?"
*              		                  12345678901234567890123456789012345678901234567890123456789012345678901234567890
	   if _rc  exit 1
	   else "Execution continues..."
	}														 // return code is consulted below
	
	else  {													 // Data were doubly-stacked
	   noi display as error _newline "Save dbly-stckd data under new name to avoid overwritng the singly-stacked file?{txt}"															
	   capture window stopbox rusure "Save doubly-stacked data under a new name to avoid over-writing the singly-stacked file?"
*              		                  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
	}
	
	if _rc==0  {											  // User responded with "OK"

	   global newfile = "`c(pwd)'`c(dirsep)'$filename"		  // These globals were saved in opening lines of stackmeWrapper
*	   global newfile = "$dirpath" + "$filename"
	   local filename = "$filename"
	   gettoken prefix filename : filename, parse("_")		  // If file already stacked, get prefix preceeding "_"

	   if "`prefix'" != "STKD" & "`prefix'" != "S2KD"  {	  // Avoid identifying doubly-stacked dataset as "S2KD_STKD_'"
		  global newfile = "$dirpath" + "STKD_" + "$filename" // (by prepending chars 'STKD_' to filename only if absent)
	      capture window fsave newfile "File in which to save stacked data" "Stata Data (*.dta)" dta
	   }
	   else  {												  // If already stacked, this pass should be double-stacking
	   	  if "`prefix'" == "STKD"  {
		  	 global filename = substr("`filename'", 2, .)	  // Strip "_" from front of `filename', left there by gettoken
		  	 global newfile ="$dirpath" +"S2KD_" +"$filename" // Stata fsave cmd expects filename in a global, not a local
			 capture window fsave newfile "File in which to save doubly-stacked data" "Stata Data (*.dta)" dta
		  }													  // Filename may well start with some other chars ending w "_"
	   } //endelse
			  
	} //endif _rc==0
	   
	if _rc==0  {											  // Previously executed cmd was captured so _rc shows response

	   capture save "$newfile"								  // If _rc is non-zero this is because file exists
	   if _rc!=0  {
		  noi display as error _newline "Overwrite existing file? (Generally a very bad idea).{txt}" 
*              		         			 12345678901234567890123456789012345678901234567890123456789012345678901234567890
		  capture window stopbox rusure "Overwrite existing file? (Not recommended)"
		  if _rc==0  {
		     if "$dblystkd"=="" noi display "Existing file will be replaced with stacked version: " _continue
			 else               noi display "Existing stacked file will be replaced with doubly-stacked version: " _continue
			 
			 local report = ""
			 save "$newfile", replace
		  }				
	   } //endif _rc==0
		 
	   else local report = "File $newfile saved."
	   global report = "`report'"
		 
	} //endif 											  	  // With default report "Not saved"

	local report = "$report"
	noisily display _newline "`report'" _continue			  // `report' SOMEHOW GOT TO BE EMPTY ON PASSING } //endif


	global newfile = ""									  	  // Empty most globals used for this command	
	global reshapeStubs = ""								  // (not $filename, relevant for any later genstacks cmds)
	global dirpath = ""
	global dblystkd = ""
	global report = ""
	
	
end //genstacks	




************************************************** program genst ********************************************


capture program drop genst										// Short command name for 'genstacks'

program define genst

genstacks `0'

end genst


************************************************** END SUBROUTINES **********************************************************
