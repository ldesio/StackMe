
capture program drop genplace			// 'Places' variables in terms of their SMstkid characteristics

										// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE
					
program define genplace									// Called from program genpl, defined after this one
														// Calls stackmeWrapper and subprogram errexit

*!  Stata version 9.0; genstats version 2, updated Aug'23 to Nov'24 by Mark

version 9.0	
														
														

										// (0) Here set stackMe command-specific options and call the stackMe wrapper program;  
										//     lines ending with "**" need to be tailored to specific stackMe commands

global errloc "genplace(0)"								// Records which codeblk is now executing, in case of Stata error

														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe `cmd'. Ensure
														// prefixvar (here INDicator) is first and its negative is last.
														
	local optMask = " INDicator(varlist) CWEight(varlist) PPRefix(string) MPRefix(string) IPRefix(string) CALl(string) " 		///**
				  + " LIMitdiag(integer -1) WTPrefixvars STKlevel TWOstep NOINDicator" 						 					// **

*					EXTradiag NODIAg REPlace NOCONtexts NOSTAcks APRefix (NEWoptions MODoptions) (+ limitdiag) are common to most 
														// stackMe cmds and are added (except limitdiag) in wrapper, codeblk(1).
														// (NOTE that options named 'NO??' are not returned in a macros named '??')
														
					// In this command we need to find which of first two options is the one to be treated as 'opt1' (the one that
					// is matched with 'prfxvar' in the command's varlist). This is determined in wrapper according to whether.
					// 'wtprefixvars' was optioned. NOTE that for other cmds we identify the var(list) to keep as named by opt #1.
														// First option in optMask has special status, generally naming a var or
														//  varlist	that may be overriden by a prefixing var or varlist (hence	
														//  the name). `prefixvar' is referred to as `opt1' in stackmeWrapper,  
														//  called below, and must be referenced using double-quotes. Its status
														//  in any given 'cmd' is shown by option 'prfxtyp' (next line).
														
	local prfxtyp = "var" /*"othr" "none"*/				// Nature of varlist prefix – var(list) or other. (NOTE that a varlist	   **
														// may itself be prefixd by a string, in which case 'prfxtyp' is 'othr'.
														
														// This command services two alternative prefixvar lists, either a (list 
														// of) indicator variable(s) or a list of cweights. These appear as the 
														// first two options. In practice one of these should be empty. As usual, 
														// options with arguments preceed toggle (aka flag) options; limitdiag 
														// should follow the last argument, followed by any flag options for this 
														// command. REPLACE ANY 'stackid' (no longer an opt) WITH 'itemname' (now 
														// required for most stackMe 'cmd's, along with 'APRefix')

	local multicntxt = "multicntxt"/*""*/				// Whether `cmd'P takes advantage of multi-context processing (morphes	   **
														//  into `noMultiContxt' in 'stackmeWrapper')
	
	local save0 = "`0'"									// Saves what user typed, to be retrieved on return to this caller prog.   **

	
*	***********************									   
	stackmeWrapper genplace `0' \prfxtyp(`prfxtyp') `multicntxt' `optMask'	// Space after "\" must go from all calling progs	   **				
*	***********************								// `0' is what user typed; `prfxtyp' & `optMask' strings were filled	
														//  above; `prfxtyp', placed for convenience, will be moved to follow 
														//  optns – that happens on 4th line of stackmeWrapper's codeblk(0.1)
														// `multicntxt', if empty, sets stackMeWrapper flag 'noMultiContxt'
*  CONtextvars NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of these except limitdiag are added in stackmeWrapper, codeblock(2)

														
														
											// *****************************
											// On return from stackmeWrapper
											// *****************************
											
* *********************														
  if "$SMreport"==""  {								// If return does not follow an errexit report
* *********************								// (exit 1 exits to caller, if any, or to Stata)

	local 0 = "`save0'"									// On return from stackmeWrapper restore what user typed
							

  capture  {											// Put remaining code within capture braces, in case of Stata error	
														// (capture processing code is at the end if this adofile)
														// (capture braces start after return from wrappr so doesn't capture same 
														//  error already captured in wrapper)											
											
	global errloc "genplace(1)"							// Records which codeblk is now executing, in case of Stata error
											

	local 0 = "`save0'"									// On return from wrapper, re-create local `0', restoring what user typed
														// (so syntax cmd, below, can initialize option contents, not done above)

*	****************															
	syntax anything, 	[ CWEight(varlist) INDicator(varlist) MPRefix(name) PPRefix(name) IPRefix(name) CPRefix(name) ]			///
/*	****************/	[ APRefix CALl(string) LIMitdiag(integer -1) WTPrefixvars NOPLUgall TWOstep EXTradiag ctxvar(string) ]	///
						[ NOContexts contextvars(varlist) nc(integer 1) nvarlst(integer 1) tempcntxt(string) wtexplst(string) *]
 						
														// This re-initializes option contents as though cmd was newly called
														
	local multivarlst = "$multivarlst"					// get multivarlst from global saved in block (6) of stackmeWrapper
											  
	local contexts = "`_dta[contextvars]'"
	if "`contextvars'"!=""  local contexts = "`contextvars'"
	local contextvars = "`contexts'"					// In this caller we don't actually make use of contextvars
	
	if `limitdiag'<0  local limitdiag = .				// If =-1 make that a very big number
	
	if "`nodiag'"!=""  local limitdiag = 0
	
	if "`mprefix'`pprefix'`iprefix'`cprefix'`aprefix'"!="" & `limitdiag' noisily display "Renaming variables as optioned"
	if "`mprefix'`pprefix'`iprefix'`cprefix'"!="" & "`aprefix'"!="" {
		errexit "Cannot option aprefix together with any other prefix option"
*				12345678901234567890123456789012345678901234567890123456789012345678901234567890
	}
	
	if "`aprefix'"!=""  {
		rename pm_* pm`aprefix'*
		rename pp_* pp`aprefix'*
		foreach var of local indicator  {
		  rename `var'_* `var`aprefix''*
		}
	}
	else  {
		if "`mprefix'"!=""  rename pm_* p`mprefix'_*
		if "`pprefix'"!=""  rename pp_* p`pprefix'_*
		if "`iprefix'"!=""  {
			foreach var of local indicator  {
				rename `var'_* p`iprefix'_`var'_*
			} //next 'var'
		} //endif
	} //endelse
	
	if "`cprefix'"!=""  {
		foreach var of local cweight  {
			rename `var'_* p`wprefix'_`var'_*
		}
	}

	noisily display _newline "done."
	

	local skipcapture = "skipcapture"						// Overcome possibility that there's a trailing non-zero return code

	
  } //end capture												// Capture brackets enclose all genst codeblks aftr return from wrapper


															// PROBLEM HERE: DON'T KNOW IF REASON FOR $EXIT==1 WAS ALREADY DISPLAYED	***
  if _rc  & "`skipcapture'"=="" {								// If there is a non-zero return code (should be captured Stata error)

	if "$exit"=="" global exit = 0							// If $exit is empty that must be because it has not yet been set
		
	if $exit==1  {											// If $exit ==1  reason will already have been diosplayed in Results wndow
		capture restore										// With $exit==1, data in memory have been changed
		use SMorigdta, clear								// (so restore original dataset)
		erase SMorigdta
		exit 1												// This was effectively a tempfile, though not declared as such
	}														// (because we needed to be able to access it from here)	
	
															// Else $exit was not set ==1
	
	display as error _newline "Likely programming error in $errloc; click on blue error code for details" _newline
*              		           12345678901234567890123456789012345678901234567890123456789012345678901234567890
	window stopbox note "Likely programming error in $errloc; after 'OK' click on blue error code for details""
    macro drop _all											// Drop all globals used to process this stackMe command
	exit _rc												// Exit with return code to be displayed by Stata

  } //endif _rc & ! `skipcapture'

  
* *****************
  } //endif $SMreport										// Close braces that delimit code skipped on return from error exit
* *****************	  
	
  global multivarlst										// Clear this global, unused above
  global SMreport											// Ditto
  global origdta											// Ditto
	
	
end //gensplace			


*************************************************** PROGRAM genpl **************************************************************


capture program drop genpl

program define genpl

genplace `0'

end genpl


************************************************* END PROGRAM genpl ************************************************************
