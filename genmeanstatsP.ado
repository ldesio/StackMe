
capture program drop genmeanstatsP				// Does the work for genmeanstats

program define genmeanstatsP

	version 9.0									// genmeanstatsP version 2.0, June 2022, updated May 2023

*!  Stata version 9.0; genmeanstatsP (new in version 2), August '23'.  Minor tweaks for new weighting stratgy Nov`24'


global errloc "genmeanstatsP"					// Global that keeps track of execution location for benefit of 'errexit'

****************
capture noisily  {								// Open capture braces mark start ot code where errors will be captured
****************	

    syntax varlist [aw fw pw/] ,  [ CONtextvars(varlist) STAts(string) SWPrefix(name) MEAPrefix(name) MEDPrefix(name)  ] ///
	[ MODPrefix(name) SDPrefix(name) MIPrefix(name) MAPrefix(name) SKPrefix(name) KUPrefix(name) LIMitdiag(integer -1) ] ///
	[ INCludemissing NOCONtextvars NOSTAcks nvarlst(integer 1) ctxvar(str) nc(integer 0) c(integer 0) wtexplst(str) *  ] 



															// Context-by-context processing IS used by genmeanstats
															
	local cmdvars = subinstr("`varlist'","||"," ",.)		// Remove "||" & save this from overwriting by next `syntax' cmd															
															// Pipes have no relevance for this cmd

												// Pre-process genmeans-specific options not preprocessed in wrapper
												// (this version does not yet have pre-processing of multi-varlists)
	
	if "`wtexplst'"!=""  {									// Needed for call on 'impute', below
		local weight =subinstr(word("`wtexplst'",`nvarlst'),"$"," ",.)
		if "`weight'" == "null"  local weight = ""			// Replace all "$" by " " (substituted to ensure 1 word per wtexp)
	}				 										// Duplicate weight expressions were handled in wrapper program		***
	
  
	if `limitdiag'==-1  local limitdiag = .					// User wants unlimitd diagnostcs, make that a very big number!		** 
												
	local count = `c'										// Count of contexts processed, as basis for limitdiag & initializtn

	while `count'==1  {										// Put required stats & correspondng statvars into globals
	
		global prfxlist = ""					// 'count'==1 CODE SHOULD ALL BE REMOVED TO genmeanstatsO						***
		global statlist = ""

		local 0 = ", `stats'"								// Local 0 is where syntx commnd expects to find user's command line
															// ('stats' is name of option in which user placed desired stats)
		syntax , [ N MEAn SD MIN MAX SKEwness KURtosis SUM SW MEDian MODe _all ] // List is also in 's0', differently formatted
															// Command 'syntax' selects those actually optioned, in 's1' below
		local s0 =     lower("N MEAn SD MIN MAX SKEwness KURtosis SUM SUOfwts MEDian MODe") // List of available stats in lower case
		local s1 = stritrim("`n' `mean' `sd' `min' `max' `skewness' `kurtosis' `sum' `sumOfWts' `median' `mode'") // r-names
		local s2 = stritrim( "N   me     sd   mi    ma    sk         ku         su    sw         md       mo"   ) // Prefix initials

		if "`_all'"!=""  {									// if "_all" was optioned
		   if wordcount("`s1'")>0 {							// if any other stats were optioned
			  errexit "Cannot option any other stats along with '_all'"
			  exit											// Invoke errexit
		   }
		   local s1 = "`s0'"								// Otherwise make like all stats were optioned
		}													// Rest of "while `count'" is same whether '_all' was optioned or not
		
		local nstats : list sizeof s1						// N of optioned stats sitting in 's1' after 'syntax' was executed
															// (same as names of r-returns, except that 'sw' should be 'sum_w'
		forvalues i = 1/`nstats'  {							// Cycle thru list of optiond stats

			local stat = word("`s1'",`i')					// Statistic `i' of optioned list (lower case if "n")
			local statpos : list posof "`stat'" in s0		// Position of that stat in full list of possible stats (in 's0')
			local px = word("`s2'",`statpos')				// (`px' now holds 2-char default prefix for generated stat)
			global prfxlist = "$prfxlist `px'"				// Append to $prfxlist in `i'-order
*			if "`stat'" == "sw"  local stat = "sum_w" 		// If optioned stats include sum of weights, replace with r-name
			if "`stat'"=="n"  local stat = "N"				// If "n" was optioned, make that "N"			
			global statlist = "$statlist `stat'"			// Append to $statlist, in i-order
			
		} //next i
		
		local count = 0										// Ensure end of while loop
		
	} //endif `count'==1									// ALL count==1 CODE SHOULD BE MOVED TO genmeanstats0 when coded	***
	

	
	
												// FOLLOWING CODE CAN STAY IN 'genmeanstatsP'

	local medmod = substr("$statlist",-4,4)					// Get last 4 chars of "$statlist"
	if "`medmod'"=="dian" | "`medmod'"=="mode" {			// If they are the last four chars of "median" or "mode" ..
	   local statlist = subinstr(subinstr("$statlist","median","",1),"mode","",1)
	}												 		// Trims off last (pair of) stats if median and/or mode
	else local statlist = "$statlist"
	
	local detail = ""										// Determine if 'summarize' cmd needs ',detail'
	if strpos("$prfxlist","sk") | strpos("$prfxlist","ku")  local detail = ", detail"
	
	
	foreach var of local cmdvars  {							// Cycle thru all vars in user-supplied varlist
	
	  if "`statlist'"!=""  {								// If 'statlist' calls for any stats besides median and/or mode ..
	  
		quietly summarize `var' `detail'
	
		local j = 0											// Index to identify word in $sum, $statlist and $prfxlist

		foreach s of global statlist  {

			local j = `j'+1									// Index to identify word in $sum, $statlist and $prfxlist
			local prfx = word("$prfxlist", `j') + "_"		// Append "_ to prefix"
			gen `prfx'`var' = r(`s')	
		
		} //next 's'
		
	  } //endif												// Whether or not we got other stats still might need median|mode
				
	  if strpos("$statlist","median") quietly egen `prfx'`var' = median(`var')
	  if strpos("$statlist","mode")   quietly egen `prfx'`var' = mode(`var')
															// DK WHY NOT GETTING THESE FROM summarize; SPEEDTEST??				***
	} //next 'var'
	
															// Empty globals after final context has been processed
															// (THIS HSOULD EVENTUALLY BE DONE IN caller PROGRAM)
															
	if `c'==`nc'  {											// If this is the final context
	
		global cmdvars = ""
		global statlist = ""
	}
	
	local skipcapture = "skipcapture"						// Local, if set, prevents capture code, below, from executing
	
	
* *************
} //end capture												// Endbrace for code in which errors are captured
* *************												// Any such error would cause execution to skip to here
															// (failing to trigger the 'skipcapture' flag two lines up)

if "`skipcapture'"==""  {									// If not empty we did not get here due to stata error
	
	if _rc  errexit, msg("Stata reports program error in $errloc") displ orig("`origdta'")
	
}
	

end genmeanstatsP



************************************************** END PROGRAM genmeans ****************************************************




