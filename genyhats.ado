
capture program drop genyhats				// Estimates inflated imputed values of listed variables for multiple imputation of
											//   contextual data (multiply-imputed thanks to the multiple context\s)

											// SEE PROGRAM stackmeWrapper (CALLED  BELOW) FOR  DETAILS  OF  PACKAGE  STRUCTURE

program define genyhats						// Called by yenyh (below); calls stackmeWrapper
																	

*!  Stata version 9.0; genyhats version 2, updated Apr'23-May'25 by Mark from major re-write in June'22

	version 9.0
											// Here set stackMe command-specific options and call the stackMe wrapper program; lines 
											// that end with "**" need to be tailored to specific stackMe commands
										
														// ADAPT LINES FLAGGED WITH TRAILING ** TO EACH stackMe 'cmd'
	local optMask = "DEPvarname(name) ITEmname(varname) ADJust(string) EFFects(string) EFOrmat(string) YDPrefix(name) "		/// **
				  + "YIPrefix(name) DPRefix(name) IPRefix(name) LIMitdiag(integer -1) MULtivariate LOGit REPlace NOReplace KEEpmissing"					    	 	//	**
														// (NOTE that prefix names appear in both version 1 & version 2 formats)**
														// Ensure prefixvar for this stackMe command is placed first and its 
														// negative is placed last; ensure options with arguments preceed toggle 
														// (aka flag) options; limitdiag should folloow last argument, followed
														// by any flag options for this command. Options (apart from limitdiag) 
														// common to all stackMe `cmd's will be added in stackmeWrapper.
														// CHECK THAT NO OTHER OPTIONS, BEYOND THE FIRST 3, NAME ANY VARIABLE(S)**

	local prfxtyp = "var"/*"othr" "none"*/				// Nature of varlist prefix – var(list) or other. (`depvarname will		**
														// be referred to as `opt1', the first word of `optMask', in codeblock 
														// (0) of stackmeWrapper called just below). `opt1' is always the name 
														// of an option that holds a varname or varlist (which must be referred
														// using double-quotes). Normally the variable named in `opt1' can be 
														// updated by the prefix to a varlist, but not so in genyhats.
		
	local multicntxt = "multicntxt"/*""*/				// Whether `cmd'P takes advantage of multi-context processing			**
	
	local save0 = "`0'"									// Seems necessary, perhaps because called from gendi
	
	
	
*	***********************									   
	stackmeWrapper genyhats `0' \ prfxtyp(`prfxtyp') `multicntxt' `optMask' // Name of stackme cmd followed by rest of cmd-line					
*	***********************								// (local `0' has what user typed; `optMask'&`prfxtyp' were set above)	
														// (`prfxtyp' placed for convenience; will be moved to follow options)
														// (that happens on fifth line of stackmeWrapper's codeblock 0)
														
*  Additionally, NODiag EXTradiag REPlace NEWoptions MODoptions NOCONtexts NOSTAcks  (+ limitdiag) ARE COMMON TO MOST STACKME COMMANDS
*														// All of those except limitdiag are added in stackmeWrapper, codeblock(2)
														
	
	
														
											// *****************************
											// On return from stackmeWrapper
											// *****************************
											
* *********************														
if "$SMreport"==""  {									// If return does not follow an errexit report
* ********************									// (if an error was reported we skip all processing otherwise done in caller)


global errloc "caller(1)"


* *********
  capture noisily {												// (begin new capture block in case of errors to follow)
* *********	
	
	local 0 = "`save0'"											// On return from stackmeWrapper restore what user typed
	
	syntax anything [aw fw pw/] , [ DEPvarname(varname) YDPrefix(name) YIPrefix(name) DPRefix(name) IPRefix(name) ] 	///
								  [ LIMitdiag(integer -1) MULtivariate NODiag REPlace NOReplace KEEpmissing * ]
	

	
	if `limitdiag' == -1   local limitdiag = .					// Make that a very big number!
	if "`nodiag'"!=""  local limitdiag = 0
	
	if "`noreplace'"!=""  local replace = "replace"				// Actual option seen by user is 'noreplace'
	
	if `limitdiag' {											// Report on clean-up operations if optioned
	
	    if "`iprefix'`mprefix'"!=""  noisily display as error "NOTE: Reassigning prefix string(s), as optioned"
	
		if "`noreplace'"!=""  local replace = ""
		if "`replace'"!=""  {
			if "`keepmissing'"==""  {
			   noisily display _newline "Dropping missing indicators and originals of yhat variables, as optioned"
			}
			else  noisily display _newline "Dropping originals of yhat variables, as optioned"
		}														// NOTE THAT THERE ARE NO MISSING INDICATORS FOR YHATS !!
		
	} //endif 'limitdiag'
	
	
	foreach str in yd yi yp  {									// Assign contents of version 2 optnames to version 1 optnames
		if "`str'prefix" !=""  {								// If version 2 optname is not empty
			local pfxopt = substr("`str'prefix",2,.)			// Create local named with 2nd to last chars of v2 option name
			local `pfxopt' = "``str'prefix'"					// Assign contents of original (v2) local to the new (v1) local
		}														// All prefix locals can now be referrenced using v1 names
	}															// (whichever version of the name was optioned)
	
	foreach str in d i m  {										// Cycle thru yhat string prefixes (using v1 naming)
	   if "`str'prefix"!=""  {									// If user optioned a different string for this prefix ...
		  local y`str'prefix = "``str'prefix'"					//   Put either "yd" or "ydprefix" into `prefix' (same for "yi")
		  if substr("``str'prefix'",-1,1)!="_"  local y`str'prefix = "``str'prefix'_"
	   }														// Add "_" to end of string if user did not include that
	   else  local y`str'prefix = "``str'prefix'"				// Else user did not option a string so assign default str
	} 

	
	
global errloc "caller(2)"



*			scalar VARLISTS`nvarlst' = "`outcomes'"				// Store in scalar where can be found by 'cmd'P and elsewhere
*			scalar PRFXVARS`nvarlst' = "`prfxvars'"				// Store in scalar the name of var(list) that preceed a colon
*			scalar PRFXSTRS`nvarlst' = "`strprfx'"				// Has string that may prefix single-var prefixvar, or has a stubname
*																// ABOVE JUST FOR REFERENCE

	local nvarlsts = NVARLSTS									// Stores n of varlists

	if "`depvarname'"=="null"  local depvarname = ""			// Default or user-optioned depvarname
	
	local isprfx = "`multivariate'" == "multivariate"			// Default or user-optd multivariate (0 if "multivariate" not optd)
	
	if "`aprefix'"!=""  {										// 'aprefix' SHOULD NORMALLY START AND END WITH "_"					***
																// This option applies to all prefixes for current 'cmd'		
		if substr("`aprefix'",-1,1)!="_"  {						// If 'aprefix' does not end with "_" ...
			local aprefix = "`aprefix'_"						// Then append one
		} 
	}
		   
	else  {														// Else aprefix was not optioned
		   	
		if "`dprefix'"!="" & substr("`dprefix'",-1,1)!="_"  local dprefix = "`dprefix'_"
		if "`iprefix'"!="" & substr("`iprefix'",-1,1)!="_"  local iprefix = "`iprefix'_"
	   	local aprefix = "_"										// If aprefix contributes nothing substantive it contributes "_"
		if "`dprefix'"=="" local dprefix = "yd"					// If d_prefix was not optioned then make it 'yd'
		if "`iprefix'"=="" local iprefix = "yi"					// If i_prefix was not optioned then make it 'yi'
			  
	} //endelse
		
	
	
	forvalues nvl = 1/`nvarlsts'  {								// Cycle thru varlists on genyhats command-line
		
		if PRFXVARS`nvl'!="" & PRFXVARS`nvl'!="null"  {			// If prefixvar is non-empty this is a multivariate analysis
			local depvar = PRFXVARS`nvl'						// Retrieve depvar name for this varlist
			local isprfx = 1									// And set isprfx flat
		}
		else  {													// Else this is a (set of) bivariate analys(es)
			local depvar = "`depvarname'"						// User-optioned depvarname, if optioned, else "null" -> empty
			local isprfx = "`multivariate'" == "multivariate"	// Default or user-optd multivariate (0 if "multivariate" not optd)
		} 
			
		local varlist = VARLISTS`nvl'										
		checkvars "`varlist'"									// Unab the varlist (using checkvars avoids occasional unab error)
		local varlist = r(checked)
		local varlist = subinstr("`varlist'",".","",.) 			// Remove any missing variable symbols


		if `isprfx'  {											// If this is a multivariate analyis
			
		   	local lbl = "yhat for `depvar'"
		   	if strlen("`lbl' (`vlbl') on `varlist'") >80 | "`vlbl'"=="" { 
																// If 80 cols isn't enough to include parenthasized depvar label..
			  	label var d_`depvar' "`lbl' on `varlist'"		//   (or is no label) then omit depvar label from the yhat label
			}
			else label var d_`depvar'  "`lbl' (`vlbl') on `varlist'"
																// Else include the parenthasized depvar label in the yhat label
			rename d_`depvar'  `dprefix'`aprefix'`depvar'		// Here dprefix is either user-optioned or "yd"
			
			if "`replace'"!=""  drop `depvar'					// SHOULD WE DROP THE DEPVAR? MAYBE ONLY INDEPS?					***

		}
		
		else  {													// Else this is a set of bivariate analyses
		
		  foreach var of local varlist  {
	  	
		     capture local vlbl : variable label `var'			// Get existing var label, if any
		   
			 label var i_`var'  "yhat for `depvar' on `var': `vlbl'" 
			 
			 rename i_`var'  `iprefix'`aprefix'`var'			// Here iprefix is either user-opptioned or "yi"

		  } //next 'var'										// aprefix is either user-optioned (ending in "_") or "_"
		   
		
		  if "`replace'"!=""  {									// If replace was optioned
			 drop `varlist'										// 'varlist' is either depvar or indep-varlist
			 if "`keepmissing'"==""  {							// Not a genyhats option
			   drop m_`var'
			 }
		  }
		  
		} //endelse

	} //next 'nvl'												// Other prefix options are handled in respective caller programs
	
	noisily display _newline "done." _newline
	

	local skipcapture = "skip"									// Flag causes execution to skip capture block if got to here
	
  } //end capture	
	
	
* *******************
  } //endif $SMreport
* *******************

  if _rc & "`skipcapture'"==""  {
  
	 errexit  "Program error while post-processing"
	 exit _rc

  }
  
  global multivarlst											// Clear this global, retained only for benefit of caller programs
  global SMreport												// And these, retained for error processing
  global SMrc												
  capture erase $origdta 										// (and erase the tempfile in which it was held, if any)
  global origdta

	
end genyhats			




************************************************* PROGRAM genyh **************************************************************

 
capture program drop genyh

program define genyh

genyhats `0'

end genyh


**************************************************** END genyh **************************************************************


