

capture program drop genstacks			 // Reshapes a dataset from 'wide' to 'long' (stacked) format

										 // SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define genstacks									// Called by 'genst' a separate program defined after this one
															// Calls subprogram stackmeWrapper and subprogram 'errexit'

*!  Stata versn 9.0; stackMe version 2, updated May'23 from major re-writes in June'22 and May'24 to include post-wrapper code
*!  See introductory comments in 'stackmeWrapper.ado' for additional details regarding code for the stackMe suite of ado files.

	version 9.0							// SEE HEAD OF PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE


global errloc "genstacks(0)"								// Records which codeblk is now executing, in case of Stata error




										// (0)  Here set stackMe command-specific options and call the stackMe wrapper program  
										// 		(lines that end with "**" need to be tailored to specific stackMe commands)
									
															// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'. Ensure
															// prefixvar (here ITEmname) is first and its negative, if any, is last.	
															
	local optMask = " ITEmname(varname) FE(namelist) FEPrefix(string) LIMitdiag(integer -1) KEEpmisstacks NOCheck " //					**

*					EXTradiag NODIAg NOREPlace NOCONtexts NOSTAcks APRefix (NEWoptions MODoptions) (+ limitdiag) are common to most
															//  stackMe cmds and are added to 'optMask' in wrapper's codeblk (1)
															// (NOTE that options named 'NO??' are not returned in a macros named '??')
	
															// For this `cmd', the first option does not have a corrspnding negative
															// counterpart, and no varlist/stublist prefixes are allowed.
*															
	local prfxtyp = /*"var" "othr"*/"none"					// Nature of varlist prefix – var(list) or other. (NOTE that, except for	**
															//  this command, a varlist	may itself be prefixd by a varlist or string
		
	local multicntxt = "multicntxt"							// Whether `cmd'P takes advantage of multi-context processing (resulting 	**
															// macro morphes into `noMultiContxt' in 'stackmeWrapper')
															
	local save0 = "`0'"										// Save what user typed, to be retrieved on return to this caller program
										

*	************************
	stackmeWrapper genstacks `0' \prfxtyp(`prfxtyp') `multicntxt' `optMask' 	// Space after "\" must go from all calling progs		**			
*	************************								// `0' is what user typed; `prfxtyp' & `optMask' strings were filled	
															//  above; `prfxtyp', placed for convenience, will be moved to follow 
															//  optns – that happens on 4th line of stackmeWrapper's codeblk(0.1)
															// `multicntxt', if empty, sets stackmeWrapper flag 'noMultiContxt'

															

								 // **************************
								 // On return from wrapper...*
								 // **************************
								 
******************							
if "$SMreport"==""  {										 // If return does not follow an errexit report
******************											 



* **********
  capture  {												 // Puts rest of command within capture braces, in case of Stata error	
* **********												 // Capture processing code is at the end if this adofile.



								// Here deal with possible errors that might follow
								
								
	global errloc "genstacks(1)"							 // Records which codeblk is now executing, in case of Stata error
									
	local 0 = "`save0'"									     // On return from wrapper, re-create local `0', restoring what user typed
															 // (so syntax cmd, below, can initialize option contents, not done above)
															
	
*	***************
	syntax anything ,  [ LIMitdiag(integer -1) ITEmname(varname) CONtextvars(varlist) NOStacks NOContexts NODiag REPlace * ]									
*	***************										    
											
	/*if `limitdiag'==0*/  noisily display " "				// No 'continue' for final busy dot

	
	
	
										// Next codeblocks post-process new variables created in genstacksP

										// (2) Make labels for reshaped vars, based on first var in each battery ...
										
														// NEED TO TREAT DOUBLY-STACKED DATA SEPARATELY								***
										
	local namelist = "$multivarlst"						// Global saved in codeblock (5) of stackmeWrapper
														// (genstacks only has a single varlist; so no "||", no ":")	
	local varlabel = ""									// Initialize a local outside foreach loop to hold eventual label	
	local response = 0									// Local at top level to register responses within if or foreach		
														// (apparently unused)														***
	foreach stub of local namelist {					// (whether specified in syntax 2 or derived from syntax 1 varlist)
	
		foreach var of varlist `stub'*  {				// Sleight-of-hand to get first var in each battery
		
			if real(substr("`var'",-1,1))==.  continue	// If final char is NOT numeric (real version IS missing)..
														// ('continue' skips rest of foreach block, continues w' next var)
			local label : variable label `var'			// See if that variable has a label		
			if "`label'"=="" {							// If this var has no label, provide dummy label
			   local varlabel = "stkd `var'"			// Use varname as label 
			   continue, break							// Break out of varlist loop because have label for stub
			}

			local loc = strpos("`label'", "==")			// Otherwise see if the label contains "==" (from gendummies)
														// (meaning it starts with the associated varname)
			if `loc'>0  & `loc'<14 {					// If contains varname, placed by 'gendummies' recover it
				
				local varname = strtrim(substr("`label'", 1,`loc'-1)) // Assume "==" follows end of varname
				capture confirm variable `varname'		// See if gendummies kept original varname at start of label			
				if _rc == 0  {							// If this word was previously a variable ...
					local label : variable label `varname' // See if that variable was labeled
					if "`label'"!=""  {
						local varlabel = "stkd `label'"
						continue, break					// Break out of foreach `var' because we found a generic label	
					}
				}										// (from the var whose categories became dummy variables)
														// Either never labeled or was renamed during gendummies
				local label : variable label `var'		// So proceed as above, providing
				if "`varlabel'"=="" {					// If this var has no label, provide dummy label
					local varlabel = "stkd `var'"		// Use varname as label 
					continue, break						// Break out of varlist loop because have label for stub
				}
				
			} //endif 'loc'	
			

			
global errloc "genstacks(2)"
			

			
			else {										// No "==" so is not from a gendummies-built battery
			
				if strpos("`label'", "`var'") > 0	{	// If it has an embedded varname ...
					local loc = strpos("`label'", "`var'")
					local label = substr("`label'",`loc'+strlen("`var'"), .)
					local cc = (substr("`label'", 1, 1))
					mata:st_numscalar("a",ascii("`cc'")) // Get MATA to tell us the ascii value of `cc'

					while (strpos("<=>?@[\/]_{|}~", "`cc'") < 1) & ("`cc'" != "") & ( (a<45 & a!=41) | a>126 )  {
					   local label = substr("`label'", 2, .) // (strpos & 41 are good; a<45 & a>126 are not)
					   local cc =(substr("`label'"),1,1) // Trim chars other than "good" above from front of label
					   mata: st_numscalar("a", ascii("`cc'"))
					}									// (the above doesnt include " " so leading spaces get trimmed)
					local varlabel = "stkd " + strtrim("`label'")
					continue, break						// Break out of foreach 'var' because 1st var is all we need
				}
				else  {									// Else no embedded varname
					local varlabel ="stkd " + strtrim("`label'") 
					continue, break						// Otherwise use label of first var, unmodified
				}
			} //end else
			
		} //next `var'									// Will break out of loop when processd 1st var w' numeric suffx
		
		
		if "`varlabel'"!=""  {							// If we found a varlabel
		
		   local varlabel = strrtrim("`varlabel'")		// Trim off any trailing blanks

		   while real(substr("`varlabel'",-1,1)) !=. {	// While final char is numeric
			  local varlabel = strtrim(substr("`varlabel'",1,strlen("`varlabel'")-1)) // shorten varlabel by one char
		   }											// Exit 'while' when last char of label is not numeric

		   if `limitdiag' != 0  noisily display "Labeling {result:`stub'}: {result:`varlabel'}"
		   quietly label var `stub' "`varlabel'"
		   
		} //endif 'varlabel'
	
	} //next `stub'										// Find next now-reshaped var needing a label
	 

	 
	 
	label var SMstkid "stkid for vars `namelist'"		// Label var SMstkid with list of stubnames that were stacked
		 
	label var SMunit "Sequential ID of observations that were units of analysis in the unstacked data"
*					  12345678901234567890123456789012345678901234567890123456789012345678901234567890

	 

	 
global errloc "genstacks(3)"
		  
									// (3) Drop unstackd versns of now stackd vars if 'replace' optiond; process any `itemname'
									
									
	if "`replace'"=="replace" {							// If  commandline contains option "replace" (or allowed abbreviation)
		varsImpliedByStubs `namelist'					// Program can be found at end of `stackmeWrapper' adofile
		local varlist = r(impliedvars)

		if `limitdiag'  noisily display _newline "As 'replace' was optioned, dropping original versions of now stacked variables"
*								                  12345678901234567890123456789012345678901234567890123456789012345678901234567890

		drop `varlist'									// 'varlist' is list of variables corresponding to syntax 2 stubs
	}													// (in syntax 1 for genstacks these would have identified each batery)
	
*														***********************************	
														// Here deal with SMitem and S2item
*														***********************************
	local act = 0										// By default take no action			
															
	if "$dblystkd"=="" {								// Data have not been doubly-stacked
		local act = 1
		local S_ = "SM"									// These substitutions may be made in 2 locations below
	}
	else  {												// else the data are double-stacked
		local act = 2
		local S_ = "S2"									// These substitutions may be made in 2 locations below
	}	
	
															
	if "`itemname'"!=""  {								// Was there an optioned itemname (name of var that will be SMitem)
														// 'itemname' was already checked to confirm it names a var
	  if "`S_'"=="SM"  local item : char _dta[SMitem]	// Retrieve name of var stored in SMitem, if any
	  else local item : char _dta[S2item]
		
	  if "`item'"=="`itemname'" noisily display "NOTE: redundant option `itemname' duplicates established `S_'item : `item'"
*				 			                     12345678901234567890123456789012345678901234567890123456789012345678901234567890
	  else  {											// Else `itemname' is different from established characteristic
		 if "`item'"!=""  {								// If characteristic is not empty
			display as error "Replace establshed `S_'item: `item' with optioned `itemname'?"
*				 			  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window stopbox rusure "Replace `S_'item characteristic `item' with `itemname'?"
			if _rc  errexit "No permission to replace `S_'item characteristic" // Exit with errexit
			else  {
				char define _dta[`S_'item] `itemname'	// Replace the characteristic
				noisily display "With previous `S_`item replaced by optioned itemname, execution continues..."
			} //endelse
		 } //endif `item'

		 else  noisily display "genstacks is defining optioned itemname `itemname' as the established `S_'item"
*				 				   12345678901234567890123456789012345678901234567890123456789012345678901234567890
		local act = 0									// Take no further action
			
		} //endelse
		
	} //endif



	
global errloc "genstacks(4)"




	else  {													// Else `itemname' was not optioned ...	
	
	  if `limitdiag' {

		 forvalues i = 1/1  {								// Dummy loop provides 'continue' exit from midst of 'if's
		
			display as error "NOTE: With no 'itemname' option, battery items are identfied only by var SMstkid{txt}"
			display as error "Is there a variable in this dataset that labels the battery items appropriately?{txt}"
*                        	  12345678901234567890123456789012345678901234567890123456789012345678901234567890
			capture window rusure ///
			"If there is a variable in this dataset that labels the battery items appropriately, can you name it?"
			if _rc==0  {
			  noisily display ///
			  "Enter the `S_'item variable name (you could have done that using the 'itemname' option)" _request(txt)
			  if "$txt"!=""  {
				capture confirm variable $txt
				if _rc==0  {
				  char define _dta[`S_'item] $txt 			// Put "`itemname'" variable name as str into S_ _dta char
				  noisily display "Variable $txt saved as `S_'item linkage variable"
				  continue, break							// Break out of dummy loop
				  
				} //endif _rc
				else  {										// Name user typed is not a valid varname
				  display as error "You can establish an `S_'item variable by using the {help SMitemname} utility program"
*                        	  		12345678901234567890123456789012345678901234567890123456789012345678901234567890
				  errexit "What you typed does not name an existing variable"  	// subprogram errexit exits the command
				}
			  } //endif $txt								// Else there was an empty response from the user
			  if "$txt" =="" errexit "Null response does not provide a variable" // subprogram errexit exits the command
			  else  capture confirm variable $txt
			  if _rc  errexit "Variable $txt does not exist"
			} //endif _rc
			
		    else {											// Else there is no suitable `S_' variable
			  noisily display "Failing that you can treat SMstkid as if it named the items it enumerates"
*                        	   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			} //endelse
			
	     } //next `i' (ie exit the quasi-loop)
		 
	  } //endif 'limitdiag'
	  
	} //endelse
	



global errloc "genstacks(5)"
								
									// (5) Tidy & rename stackMe special vars if optioned ...
									
	local contexts :  char _dta[contextvars]				// Need this to generate SMnstks and SMmxstks
	
	if "$dblystkd"==""  {									// If this dataset has just been stacked for first time
	   label var SMstkid "Sequential ID of stacks that were battery items in the unstacked data"
	   tempvar SMnstks
	   egen `SMnstks' = max(SMstkid), by(`contexts')		// Tidy the SM variables created while stacking
	   qui replace SMnstks = `SMnstks'
	   label var SMnstks "Number of stacks for each context in the single-stacked data"
	   drop `SMnstks'										// for some reason I get an error when I order these separately
	   tempvar SMmxstks
	   egen `SMmxstks' = max(SMstkid)
	   qui replace SMmxstks = `SMmxstks'
	   label var SMmxstks "Maximum N of stacks for any context in the single-stacked data"
	   drop `SMmxstks'
	}
	
	else {													// If this dataset has just been doubly-stacked
	   label var S2stkid "Sequential ID of secondary stacks in the double-stacked data"
	   tempvar S2nstks
	   egen `S2nstks' = max(S2stkid), by(`contexts')
	   qui replace S2nstks = `S2nstks'
	   label var S2nstks "Number of secondary stacks for each context in the double-stacked data"
	   drop `S2nstks'  // 12345678901234567890123456789012345678901234567890123456789012345678901234567890
	   tempvar S2mxstks
	   egen `S2mxstks' = max(S2stkid)
	   qui replace S2mxstks = `S2mxstks'
	   label var S2mxstks "Maximum N of stacks for any context in the double-stacked data"
	   drop `S2mxstks'
	}
	
	
	
	
									// (6)  Name the stacked (or doubly-stacked) file
	  	   
	
global errloc "genstacks(6)"								  // Store message locating source of any reported error

	   
	local report = "not saved."								  // Default is to save nothing
	
	if "$dblystkd"==""  {
	   noi display as error _newline "Stacked dataset needs a filename that starts with STKD_{txt}"															
	   capture window stopbox rusure "Stacked dataset needs a filename that starts with STKD_ ; OK?"
*              		                  12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}														 // return code is consulted below

	else  {													 // Data were doubly-stacked
	    noi display as error _newline "Doubly-stacked dataset needs filename that starts with S2KD_{txt}"															
	    capture window stopbox rusure "Doubly-stacked dataset needs filename that starts with S2KD_ ; OK?"
*              		                  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
	}
	
	if _rc  {												// How did user respond?
		errexit "Absent user permission to save a new file" // User responded with 'cancel' so exit after message
	}
	
	else noisily display "Execution continues..."

	global newfile = "$fullname"		  					// Global saved in opening lines of stackmeWrapper
	local filename = "$SMfilename"							// Filename presumed to be name of this file
	gettoken prefix rest : filename, parse("_")		  		// If file was already stacked, get prefix preceeding "_"
	if "`rest'"==""	{										// If 'tail' is empty there was no "_"
	   local prefix = "UNSTKD"								// Would never have that prefix; ensures next 'if' selects it
	}

	if "`prefix'" != "STKD" & "`prefix'" != "S2KD"  {		// Avoid identifying doubly-stacked dataset as "S2KD_STKD_'"
	   global newfile = "$SMdirpath" + "STKD_"+"`filename'" // (by prepending chars 'STKD_' to filename only if absent)
	   capture window fsave newfile "File in which to save stacked data" "Stata Data (*.dta)|*.dta" dta
	}														// window fsave expects new filename to be a global
	else  {													// If already stacked, this cmd should be double-stacking
	   if "`prefix'" == "STKD"  {							// WRAPPER SHOULD HAVE ENSURED CONFORMITY OF FILENAME
		  global filename = substr("`filename'", 2, .)		// Strip "_" from front of `filename', left there by gettoken
		  global newfile ="$SMdirpath"+"S2KD_" +"$filename".dta // Stata fsave cmd expects filename in a global, not a local
		  capture window fsave newfile "File in which to save doubly-stacked data" "/*Stata Data (*.dta)|*.dta" dta*/
	   }													// NOTE: ABOVE filename IS NOT $SMfilename NAMING ORIGINAL FILE
	} //endelse
	   	   
	if _rc==0  {											// User supplied a filename
	
	  capture save $newfile
	
	  if _rc!=0  {											// If file already exists..
	  	
		noi display as error _newline "Overwrite existing file?{txt}" 
*              		         		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
		capture window stopbox rusure "Overwrite existing file?"
		if _rc==0  {										// If user responded with 'OK'
		    if "$dblystkd"=="" {
			   noi display "Newly-stacked file will replace existing $newfile"
*              		        12345678901234567890123456789012345678901234567890123456789012345678901234567890
			}
			else  noi display "New doubly-stacked file will replace $newfile"		
			save $newfile, replace
			
			if "$dblystkd"==""  global SMfilename = "STKD_$SMfilename"
			else  global SMfilename = "S2KD_$SMfilename"	// Add appropriate prefix to original filename
			
			local report = "file $newfile saved."
			
		} //endif _rc
		
	  } //endif _rc!=0
	  
	} //endif _rc==0										// File was not save if this return code was not zero
	
	else  {
	  display as error "Restore unstacked datafile?"
	  capture window stopbox rusure "Restore unstacked datafile? (click 'cancel' to retain stacked file in memory)"
	  if _rc  local report = "Stacked datafile has been retained in memory but not saved."
	  else   {
	  	use $origdta', clear
		local report = "Original unstacked datafile has been restored to active memory"
	}

	
	noisily display _newline "`report'" _newline
	
	
	
	
	
	local skipcapture = "skipcapture"						// Overcome possibility of trailing non-zero return code from above

*	 ************
  } //end capture											// The capture brackts enclose just codeblocks since return from wrappr
*	 ************ 
  


  if _rc & "`skipcapture'"=="" & "$SMreport"=="" {			// If there is a non-zero return code not already reported
															// (user errors should have been caughte in wrapper pre-processing)
	local rc = _rc											// Save _rc which will be re-used below
															
	local err = "Stata reports error `rc' during post-processng"
	display as error "`err'; retain (partially) processd dta?"
*              		  12345678901234567890123456789012345678901234567890123456789012345678901234567890
	window stopbox rusure ///
	"`err'; retain partially post-processed data in memory and clean it up yourself – ok?"
	if _rc  {
		display as err "Absent ok for retaining data to post-process, unstacked data will be restored"
*              		    12345678901234567890123456789012345678901234567890123456789012345678901234567890
		window stopbox note "Absent ok for retaining data to post-process, on 'OK' unstacked data will be restored before exit"
		use $origdta, clear
	}
	else {													// Else 'ok' was clicked
		rename `genstdta' genst.dta 
		errexit "Processed data is saved in file 'genst.dta'"
	}

  } //endif _rc & ! `skipcapture'
  

* *************
} //end capture												// Close the braces that captured any errors since re-entry from wrapper
* *************  

  *****************
} //endif $SMreport											// Close braces that delimit code skipped on return from error exit
  ****************

  global multivarlst										// Clear this global, retained only for benefit of caller programs
  global SMreport											// And this one
  global origdta											// And this one

 
end genstacks	


************************************************** program genst *********************************************************


capture program drop genst									// Short command name for 'genstacks'

program define genst

genstacks `0'

end genst


*************************************************** END PROGRAMS **********************************************************
