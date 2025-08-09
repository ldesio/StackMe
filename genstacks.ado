
capture program drop genstacks			 // Reshapes a dataset from 'wide' to 'long' (stacked) format

										 // SEE  PROGRAM  stackmeWrapper  (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

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
								 
				
*															********************************************************************** 
															// THIS CALLER PROGRAM IS THE ONLY ONE TO DO EXTENSIVE POST-PROCESSING
															// (HAVING SKIPPED POST-PROCESSING, AT END OF WRAPPER, FOR OTHER CMDS)
*															**********************************************************************

*  ******************										**********************************************
   if "$SMreport"==""  {									// If return does not follow an errexit report
*. ******************										// (if it does, skip all until end of program) 
*															**********************************************


* ***************
  capture noisily {											 // Puts rest of command within capture braces, in case of Stata error	
* ***************												 // Capture processing code is at the end if this adofile.


								
								
	global errloc "genstacks(1)"							 // Records which codeblk is now executing, in case of Stata error
									
	local 0 = "`save0'"									     // On return from wrapper, re-create local `0', restoring what user typed
															 // (so syntax cmd, below, can initialize option contents, not done above)
															
															 // genstacks has its own closing codeblocks (below), not sharing code
*	***************											 // with other commands, unlike other stackMe commands
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
			   local varlabel = "stkd `var'"			// Use varname as dummy label 
			   continue, break							// Break out of varlist loop because found label for stub
		   }

		   local loc = strpos("`label'", "==")			// Otherwise see if the label contains "==" (from gendummies)
														// (meaning it starts with the associated varname)
		   if `loc'>0  & `loc'<14 {						// If contains varname, placed by 'gendummies' recover it
				
			  local varname = strtrim(substr("`label'", 1,`loc'-1)) // Assume "==" follows end of varname
			  capture confirm variable `varname'		// Confirm gendummies kept original varname at start of label			
			  if _rc == 0  {							// If this word was previously a variable ...
				 local label : variable label `varname' // See if that variable was labeled
				 if "`label'"!=""  {
					local varlabel = "stkd `label'"
					continue, break						// Break out of foreach `var' because we found a generic label	
				 }										// (from the var whose categories became dummy variables)
			  }	
														// Either never labeled or was renamed during gendummies
			  local label : variable label `var'		// So proceed as above, providing
			  if "`varlabel'"=="" {						// If this var has no label, provide dummy label
				 local varlabel = "stkd `var'"			// Use varname as label 
				 continue, break						// Break out of varlist loop because have label for stub
			  }
				
		   } //endif 'loc'	
			

			
global errloc "genstacks(2)"
			

			
			else {											// No "==" so is not from a gendummies-built battery
			
			   if strpos("`label'", "`var'") > 0	{		// If it has an embedded varname ...
				  local loc = strpos("`label'", "`var'")
				  local label = substr("`label'",`loc'+strlen("`var'"), .)
				  local cc = (substr("`label'", 1, 1))
				  mata:st_numscalar("a",ascii("`cc'")) 		// Get MATA to tell us the ascii value of `cc'

				  while (strpos("<=>?@[\/]_{|}~", "`cc'") < 1) & ("`cc'" != "") & ( (a<45 & a!=41) | a>126 )  {
					 local label = substr("`label'", 2, .)	// (strpos & 41 are good; a<45 & a>126 are not)
					 local cc =(substr("`label'"),1,1) 		// Trim chars other than "good" above from front of label
					 mata: st_numscalar("a", ascii("`cc'"))
				  }										// (the above doesnt include " " so leading spaces get trimmed)
				  local varlabel = "stkd " + strtrim("`label'")
				  continue, break							// Break out of foreach 'var' because 1st var is all we need
			   }
			   else  {									// Else no embedded varname
				  local varlabel ="stkd " + strtrim("`label'") 
				  continue, break							// Otherwise use label of first var, unmodified
			   }

			} //endelse if 'loc'
			
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

	local contexts = "`_dta[contextvars]'"				// Get contextvars as basis for generating SMnstks and SMaxtk
	
	if "$dblystkd"==""  {								// If this was the primary genstacks operation
/*		tempvar rank
		qui egen `rank' = rank(SMstkid), field by(`contexts') // Unique values taken on by SMstkid
		qui egen SMnstks = max(`rank'), by(`contexts') // Max rank (which is the number of different ranks) NOT WORKING				***
		label var SMnstks "Number of stacks identified by SMstkid per context"
*/		qui egen SMaxstk =max(SMstkid), by(`contexts') // Max value of SMstkid per context
		label var SMaxstk "Maximum value of SMstkid per context"
	}
	else  {												// Else this genstacks run doubly-stacked the data
		tempvar rank
/*		qui egen `rank' = rank(S2stkid), field by`(contexts') // Unique values taken on by SMstkid		   NOT WORKING				***
		qui egen S2nstks = count(`rank'), by(`contexts') // Max rank (which should be the number of different ranks)
		label var S2nstks "Number of stacks identified by S2stkid per context"
*/		qui egen S2axstk = max(S2stkid), by(`contexts')	
		label var S2axstk "Maximum value of S2stkid per context"
	}

	 

	 
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
			if _rc  {
				errexit "No permission to replace `S_'item characteristic" // Exit with errexit
				exit
			}
			else  {
				char define _dta[`S_'item] `itemname' // Replace the characteristic
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
				  exit
				}
			  } //endif $txt								// Else there was an empty response from the user
			  if "$txt" =="" errexit "Null response does not provide a variable" // subprogram errexit exits the command
			  else  capture confirm variable $txt
			  if _rc  {
			  	errexit "Variable $txt does not exist"
				exit
			  }
			} //endif _rc
			
		    else {											// Else there is no suitable `S_' variable
			  noisily display "Failing that you can treat SMstkid as if it named the items it enumerates"
*                        	   12345678901234567890123456789012345678901234567890123456789012345678901234567890
			} //endelse
			
	     } //next `i' (ie exit the quasi-loop)
		 
	  } //endif 'limitdiag'
	  
	} //endelse
	



global errloc "genstacks(5)"
	
	
	
									// (6)  Name and label the stacked (or doubly-stacked) file
	  	   
	
global errloc "genstacks(6)"								  // Store message locating source of any reported error

	   
	local report = "not saved."								  // Default is to save nothing
	
	if "$dblystkd"==""  {
	  noi display as error _newline "Newly-stacked dataset should be saved whose filename starts with STKD_{txt}"															
	  capture window stopbox rusure "Newly-stacked dataset should be saved whose filename starts with STKD_ ; OK?"
*              		                  12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}														 // return code is consulted below

	else  {													 // Data were doubly-stacked
	  noi display as error _newline "Newly double-stacked dataset should be saved whose filename starts with S2KD_{txt}"															
	  capture window stopbox rusure "Newly double-stacked dataset should be saved whose filename starts with S2KD_ ; OK?"
*              		                  12345678901234567890123456789012345678901234567890123456789012345678901234567890	
	}
	
	if _rc  {												// How did user respond?
		local nofile = "nofile"
/*		noisily display "Absent user permission to save a new file, file remains unsaved" // User responded with 'cancel'
		noisily display "You will need to use {help SMutilities##SMfilename} to establish its stacked status"
*              		     12345678901234567890123456789012345678901234567890123456789012345678901234567890	
		window stopbox note "Absent user permission to save a new file, file remains unsaved"
*/
	}
	
	else  {													// Otherwise amend filename and dirpath in dataset characteristics
					
	  local filename : char _dta[filename]					// Filename generally established by setcontexts
	  local dirpath  : char _dta[dirpath]					// Dirpath generally established by setcontexts
															// (dirpath ends with dirsep – "/" or "\")
	  gettoken prefix rest : filename, parse("_")		  	// If file was already stacked, get prefix preceeding "_"

	  if "`prefix'" != "STKD" & "`prefix'" != "S2KD"  {		// Avoid identifying doubly-stacked dataset as "S2KD_STKD_'"
	    global newfile = "`dirpath'" +"STKD_"+ "`filename'" // Prepend chars 'STKD_' to filename)
	  }
	  if "`prefix'"=="STKD"  {								// WRAPPER SHOULD HAVE ENSURED CONSISTENCY WITH $dblystkd				***
	    global newfile = "`dirpath'" + "S2KD_"+"`filename'" // (by prepending chars 'S2KD_' to filename)
	    global dblystkd = "dblystkd"						// In case that global had lost its content
	  }														// window fsave expects new filename to be a global

	  capture window fsave newfile "Edit name and/or choose folder for file in which to save stacked data" "Stata Data (*.dta)|*.dta" dta
*              		                12345678901234567890123456789012345678901234567890123456789012345678901234567890	
	
	  if _rc  local nofile = "nofile"						// Deal with this below

	
	  else {												// Else user supplied a filename
	
	    capture save $newfile	
	
	    if _rc!=0  {										// If file already exists..
		
		   noi display
		
		   while "$newfile"=="`dirpath'`filename'" {		// Repeat until get new filename
		      local dupname  = "dup"
			  noi display as errlr "You cannot overwrite the file you are 'use'ing!"
			  window stopbox note "You cannot overwrite the file you are 'use'ing!"
			  capture window fsave newfile "Edit name and/or choose folder for file in which to save stacked data" "Stata Data (*.dta)|*.dta" dta
		   } //next 'while'
		   
		   if _rc & "`dupname'"!="" local nofile = "nofile"	// Deal with this below

		   	
		   else  {	  										// Else user supplied a varname
		   	
			  capture save $newfile
			  
			  if _rc!=0  {
			  	
				 noi display as error _newline "Overwrite existing file?{txt}" 
*              		         		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
				 capture window stopbox rusure "Overwrite existing file?"
		   
				 if _rc==0  {								// If user responded with 'OK'
					   
					if "$dblystkd"=="" {
				       noi display as error "Newly-stacked file replaces existing file"
*              		        12345678901234567890123456789012345678901234567890123456789012345678901234567890
					}
					else  noi display as error "Newly double-stacked file replaces existing file"	
			   
					local nameloc = strrpos("$newfile","`c(dirsep)'")+1 // Loc of first char after FINAL (strRpos) "/" or "\" of
					global SMdirpath = substr("$newfile",1,`nameloc'-1) // `dirpath' ends w last `c(dirsep)' (i.e. before name)
					global SMfilename = substr("$newfile",`nameloc',.)  // Update filename with latest filename saved or used 
					char define _dta[filename] "$SMfilename"			 // Establish this filename as characteristic of dataset	
					char define _dta[dirpath] "$SMdirpath"				 // And the directory path to that name

					save "$newfile", replace				// IF THIS DOES NOT PRINT WHEN RUNNNG, MAY NEED TO UNCOMMENT 			***
															// THE NOISILY DISPLAY, BELOW
					local report = "file $newfile  saved."
				 
				 } //endif _rc								// User did not respond with "ok"
		   
				 else  local nofile = "nofile"				// _rc!=0 (another type of failure to supply a filename)
			  
			  } //endif _rc
			   
		   } //endelse _rc
		   
															// (user did not respond with 'ok')
	    } //endif _rc!=0
	   	  
	  } //endelse _rc 										// File was not saved if this return code was not zero
	
		
	  if "`nofile'"!=""  {									// If no new file has been established with stacked data
	
		display as error "Restore previous datafile?"
		capture window stopbox rusure "Restore previous datafile? (click 'cancel' to retain modified file in memory)"
*              		        		   12345678901234567890123456789012345678901234567890123456789012345678901234567890
		if _rc  local report = "Modified datafile has been retained in memory but not saved."
		else   {
			use $origdta', clear
			local report = "Original unstacked datafile has been restored to active memory."
	    }

	  } //endif 'nofile'
	
	  else  {												// Else establish the data characteristics for the new file

		local nameloc = strrpos("$newfile","`c(dirsep)'")+1 // Loc of first char after FINAL (strRpos) "/" or "\" of dirpath
		global SMdirpath = substr("$newfile",1,`nameloc'-1) // `dirpath' ends w last `c(dirsep)' (i.e. 1 char before name)
		global SMfilename = substr("$newfile",`nameloc',.)	// Update filename with latest filename saved or used by Stata
		char define _dta[filename] "$SMfilename"			// Establish this filename as characteristic of dataset	
		char define _dta[dirpath] "$SMdirpath"				// And the directory path to that name
		
		save "$newfile", replace							// (This might be the second time saving the same file!)
		
		local report = "File $newfile saved."
		
	  }
	
	} //endelse _rc
	
	noisily display "`report'"
	
	
	local skipcapture = "skip"								// Set flag to indicate no errors were found in captured codeblocks
															// (this line of code only executes if no errors in above codeblks)
	
*	*************
  } //end capture											// The capture braces enclose just codeblocks since return from wrappr
*	************* 
  


  if _rc & "`skipcapture'"=="" & "$SMreport"=="" {			// If there is a non-zero return code not already reported
															// (user errors should have been caughte in wrapper pre-processing)
	global SMrc = _rc										// Save _rc which will be re-used below
															
	local err = "Stata reports error $SMrc during post-processng"
	display as error "`err'; retain dta in memory?"
*              	12345678901234567890123456789012345678901234567890123456789012345678901234567890
	capture window stopbox rusure "`err'; retain partially post-processed data in memory and clean it up yourself – ok?"
	
	if _rc  {
		display as err "Absent ok for retaining data to post-process, unstacked data will be restored"
*              		    12345678901234567890123456789012345678901234567890123456789012345678901234567890
		errexit, msg("Absent permission to retain data for post-processing, on 'OK' unstacked data will be restored before exit")
		use $origdta, clear
		exit $SMrc
	}
	
	else {													// Else 'ok' was clicked
		errexit "(Partially) post-processed data is retained in memory."
		exit $SMrc
	}

  } //endif _rc & ! `skipcapture'
  


    *****************
  } //endif $SMreport										// Close braces that delimit code skipped on return from error exit
    *****************


  
  capture erase $origdta 									// Erase the tempfile that held the unstacked data, if any as yet)
  capture confirm existence $SMrc 							// Confirm whether $SMrc holds a return code
  if _rc==0  scalar RC = $SMrc 								// If return code indicates that it does, stash it in scalar RC
  else scalar RC = 98765									// Else stash an unused return code
  if $limitdiag !=0 & RC == 98765  noisily display _newline "done."	// Display "done." if no error was reported, by Stata or by stackMe
  macro drop _all											// Drop all macros (including $SMrc, if extant)
  if RC != 98765  local rc = RC 							// Set local if scalar does not hold the word "null" (assigned just above)
  scalar drop _all 											// Drop all scalars, including RC


  
  
  exit `rc'													// Local 'rc' will be dropped on exit
 
 
 
end genstacks	



************************************************** program genst *********************************************************


capture program drop genst									// Short command name for 'genstacks'

program define genst

genstacks `0'

if _rc  exit _rc

end genst


*************************************************** END PROGRAMS **********************************************************


/*
		local contexts :  char _dta[contextvars]				// Need this to generate SMnstks and SMmxstks
		sum `contexts'
		tempvar rank
		qui egen `rank' = rank(SMstkid), field by(`contexts')   // Unique values taken on by SMstkid
		tab1 `rank'
		qui egen SMnstks = max(`rank'), by(`contexts') 			// Max rank (which should be the number of different ranks)
		label var SMnstks "Number of stacks identified by SMstkid per context"
																// THIS DOES NOT PRODUCE VALUES OF SMstkid AS EXPECTED
*/
