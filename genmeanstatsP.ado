
capture program drop genmeanstatsP				// Does the work for genmeanstats

program define genmeanstatsP

	version 9.0									// genmeanstatsP version 2.0, June 2022, updated May 2023

*!  Stata version 9.0; genmeanstatsP (new in version 2), August '23'.  Minor tweaks for new weighting stratgy Nov`24'


global errloc "genmeanstatsP"					// Global that keeps track of execution location for benefit of 'errexit'

*capture noisily  {								// Avoids "} is not a valid command name" on final "}"
****************								// COMMENTED OUT 'COS PROBLEM WAS FIXED SO CLUGE NOT NEEDED
capture noisily  {								// Open capture braces mark start ot code where errors will be captured
****************	

    syntax varlist [aw fw pw/] ,  [ CONtextvars(varlist) STAts(string) SWPrefix(name) MEAnprefix(name) MEDianprefix(name)  ] ///
	[ MODeprefix(name) SDPrefix(name) MINprefix(name) MAXprefix(name) SKEwprefix(name) KURtprefix(name) LIMitdiag(integer -1)] ///
	[ INCludemissing NOCONtexts NOSTAcks nvarlst(integer 1) ctxvar(str) nc(integer 0) c(integer 0) wtexplst(str) *  ] 

															// SYNTAX COMMAND WILL BE USED AGAIN, below to parse the stats-list

															// Context-by-context processing IS used by genmeanstats
		
															// Pre-process genmeanstats-specific options not preprocessed in wrapper
  
	if `limitdiag'==-1  local limitdiag = .					// User wants unlimitd diagnostcs, so make that a very big number!			** 
															
/*	scalar NVARLSTS = `nvarlst'								// Puts in scalar # of current varlist; ultimately n of varlists
	scalar VARLISTS`nvarlst' = "`input'"					// Store in scalar where can be found by 'cmd'P and elsewhere
	scalar PRFXVARS`nvarlst' = "`prfxvar'"					// Store in scalar the name of var(list) that preceed a colon
	scalar PRFXSTRS`nvarlst' = "`strprfx'"					// String may prefix a prfxvar(list) – only one per prfxvar(list)
*/															// ABOVE COPIED FROM 'wrapper(2.1)'

	local nvarlsts = NVARLSTS
	
	foreach nvl of local nvarlsts  {						// Scalar NVARLSTS was established in 'wrapper(2.1)'

	   if "`wtexplst'"!=""  {								// Needed for call on 'summarize', below
		  local weight = word("`wtexplst'", `nvl')
		  if "`weight'" == "null"  local weight = ""
		  else  {
			 local weight = "[" + subinstr(word("`wtexplst'",`nvl'),"$"," ",.) + "]"
		  }													// Replace all "$" by " " (substituted to ensure 1 word per wtexp)
		  
	   } //endif `wtexplst'				 					// Duplicate weight expressions were handled in wrapper program				***
		

	   local medmod = substr("$statrtrn",-4,4)				// Get last 4 chars of "$statrtrn" (what user picked – est in wrapper(3))
	   if "`medmod'"=="dian" | "`medmod'"=="mode" {			// If they are the last four chars of "median" or "mode" ..
		  local picklist = subinstr(subinstr("$statrtrn","median","",1),"mode","",1)
	   }												 	// Make `statlist' a copy of $statlist excluding median and/or mode
	   else local picklist = "$statrtrn"					// Else make `picklist' an exact copy of $statrtrn
															// ($statlist was initialized in 'wrapper(3)')
	   local detail = ""									// Determine if 'summarize' cmd needs 'detail' option
	   	
	   if strpos("`picklist'","sk") | strpos("`picklist'","ku") local detail = ", detail"
															// If either of them has a non-zero position in `picklist', set `detail'
	   local varlist = VARLISTS`nvl'						// Extract current varlist from scalar VARLISTS (from 'wrapper'(2.1))

	   local nstats = wordcount("`stats'")					// Number of stats to cycle thru for each variable
															// (global statprfx was established in 'wrapper'(3): stats picked by user)
	   foreach var of local varlist  {						// Cycle thru all vars in user-supplied varlist
	   
		  if `nstats'>0  {									// If there are any stats optioned beyond `mean' and `mode' 
															// (these were removed above and will be processed below)
			 quietly summarize `var' `weight' `detail'
					
			 forvalues i = 1/`nstats'  {

			   local rtrn = word("$statrtrn",`i')			// Retrieve relevant `return' name to access 'summarize' results
			   if "`rtrn'"=="n"  local rtrn = "N"			// Options are lower case but "n" must be capitalized as a return name
			   if "`rtrn'"=="sweights"  local rtrn ="sum_w" // User options "sweight" to get stat returned in r(sum_w)
			   local prfx = word("$statprfx",`i') + "_"		// Retrieve relevant prefix; append "_" to that `prfx'
			   local interim = r(`rtrn')
			   gen `prfx'`var' = `interim'
		
			 } //next 'i'
			 
		  } //endif `nstats'>0
															// "median" & "mode" were removed from local statlist but not from the global
		  if strpos("$statlist","median") quietly egen mi_`var' = median(`var')
		  if strpos("$statlist","mode")   quietly egen mo_`var' = mode(`var')
															
	   } //next 'var'
	
	
	   
	} //next `nvl'
	
	local skipcapture = "skipcapture"						// Local, if set, prevents capture code, below, from executing
	
	
* *************
} //end capture												// Endbrace for code in which errors are captured
* *************												// Any such error would cause execution to skip to here
															// (failing to trigger the 'skipcapture' flag two lines up)

if "`skipcapture'"==""  {									// If not empty we did not get here due to stata error
	
	if _rc  errexit, msg("Stata reports program error in $errloc") displ orig("`origdta'")
	
}
	

end genmeanstatsP


************************************************** END PROGRAM genmeanstatsP ****************************************************




