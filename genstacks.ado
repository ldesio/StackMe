
program drop genstacks

program define genstacks

	version 9.0
	syntax namelist, [CONtextvars(varlist)] [STAckid(name)] [ITEmname(name)] [TOTstackname(name)] [REPlace] [RESpid(name)] [NOCheck] [fe(namelist)] [FEPrefix(string)]
	
	*** SOMEHOW this version fails to process itemname, totstackname, fe or feprecix (what are those last two?)
	
	
	gettoken firststub otherstubs: namelist					// Need `firststub' as "master battery" for diagnostics
	
	// namelist contains stubs
	// stackvars contains vars which identify a set of PTVS: e.g. cid respid

	set more off
	
	display in smcl
	display as text

	display "{text}{pstd}"
	
		
		
		
					// Diagnosing batteries with different sizes: 
		
		if ("`nocheck'"!="nocheck") {
		
			local diffsize = 0
			local previousvarsize = 0
			foreach stub of local namelist {
				local varexists = 0

				
				foreach var of varlist `stub'* {
					
					// if what comes after the stub is not numeric, skip
					// this is useful if different batteries share part of the stub (e.g. rsym and rsymp)
					local strindex = substr("`var'",strlen("`stub'")+1,.)
					//display "`strindex'"
					
					if (real("`strindex'")==.) continue
					
					local varexists = `varexists' + 1
				}
				
				
				if (`varexists'==0) {
					// unreachable anyway: it stops earlier with an error 
					display "No variables starting with {bf:`stub'}"
					exit
				}
				else {
					display "Battery {bf:`stub'} contains `varexists' variables{break}"
				}
				
				
				// LDS Jan 2020: moved here (standard practice: it previously was at the beginning the loop, where it did not make sens), and added nonzero check. Now it works.
				if (`previousvarsize'!=0 & `varexists'!=`previousvarsize') local diffsize = 1		
				
				
				local previousvarsize = `varexists'
			}
			display ""
			if (`diffsize'==1) {
				display "ERROR: Not all batteries have the same size!"
				display "Processing stopped."
				error 416
			}
		}
		
		
		
		//local itemlist = ""
				
		foreach var of varlist `firststub'* {
			local strindex = substr("`var'",strlen("`firststub'")+1,.)
			if (real("`strindex'")==.) continue
			
			//local itemlist = "`itemlist'`strindex',"
			local itemlist `itemlist' `strindex'
			
		}
		
		
*		display "***`itemlist'***"
		display "{text}{pstd}"

		noisily display _newline ".." _continue
		
		local error = 0
		
		foreach stub of local otherstubs {
			
			foreach var of varlist `stub'* {

				local strindex = substr("`var'",strlen("`stub'")+1,.)
				
				if (real("`strindex'")==.) continue
				
				local thisindex = real("`strindex'")
				local thislist `thisindex'
				
				local isinlist : list thislist in itemlist
				
				if (`isinlist'==0) {
					display as error "ERROR: battery {bf:`stub'} includes item with code {bf:`strindex'}, which is not present in master battery {bf:`firststub'}.{break}"
					local error = 1
				}
			}
			if (`error'==1) {
				display " {break} {break}"
			}
			display "." _continue
		}
		
		if (`error'==1) {
			display "Processing stopped."
			error 416
		}
	
					// End of diagnostics
					
					
	
	noisily display "." _continue
			
	/*	
	capture drop _respid
	egen _respid=fill(1/2)
	local stkvars = "_respid"
	*/
	
	
					// Enumerate all contexts
	if ("`contextvars'" == "") {
		//display "not set"
		capture drop _ctx_temp
		gen _ctx_temp = 1
		local ctxvar = "_ctx_temp"
		//local stkvars = "_ctx_temp `stackvars'"
	}
	else {
		
		capture drop _ctx_temp
		capture label drop _ctx_temp
		quietly _mkcross `contextvars', generate(_ctx_temp) missing
		
		//display "contextvar set as `contextvar'"
		local ctxvar = "_ctx_temp"
		//local stkvars = "`stackvars'"
	}
	
	noisily display "." _continue
	
	
	

					// Get varlist and resondent ID
	local varlist = ""
	foreach stub in `namelist'  {
		local varlist = "`varlist' `stub'* "
	}

*	tempvar respid								// Gets lost between files
	if strlen("`respid'") == 0  {
		bysort _ctx_temp: gen _respid = _n				// No `respid' in options
	}
	else _respid = `respid'
	
	display "."	_newline "WARNING: {bf:genstacks} saves a number of temporary files whose names start with '_'. They will " 
	display "         be stored in your active directory, in case you need to delete them manually." _newline

	save "_genstacks_orig.dta"						// **** Saved because of restore glitch

	display " "



					// Reshape (stack) each context, append them to stacked file, context by context
					
	quietly summarize _ctx_temp, meanonly
	local max = r(max)
	noisily display "Reshaping optioned variables into temporary '_genstacks#.dta' files with max # = `max' "	
	noisily display "Illustration for first context follows ..." _newline

	keep _ctx_temp _respid `varlist'					// Keep only id vars and vars being reshaped
	
	quietly summarize _ctx_temp, meanonly
	local max = r(max)
	
	quietly levelsof _ctx_temp, local(C)	

	local appendlist = ""							// List of filenames for successive contexts
	local count = 0								// Could use `c' but that would be a hostage to fortune
	foreach c of local C  {	
		local count = `count' + 1
		local stackfile "_genstacks`c'"
*		tempfile `stackfile'						// Does not appear to be discarded on exit.

		preserve							// Preserve default dataframe
		
			quietly keep if _ctx_temp==`c'				// Keep just the context to be reshaped
			if `count'==1  {
			  reshape long `namelist', i(_respid) j(stack)		// Get reshape summary table and save 1st context
			  quietly save "_genstacks_stkd.dta"
			}
			else  {							// Here suppress summary table and save to appendlist
			  quietly reshape long `namelist', i(_respid) j(stack)
			  quietly save "`stackfile'.dta"
			  local appendlist "`appendlist' `stackfile'" 		// Save subsequent stacked files, appending names to `appendlist'
			  if int(trunc(`count'/5)) * 5 == `count'  display "." _continue		
			}
			
		restore								// Restore initial data works fine within loop but, on exiting
	}									//  the loop, we find ourselves back with _genstacks_stkd.dta
	display " "	_newline
	

global appendlist = "`appendlist'"						// In case we want to exit here while debugging
*exit

local appendlist = "$appendlist"						// First command after resuming execution

	use "_genstacks_orig.dta", clear nolabel				// Work-around restores original data, needed 'cos restore fails

	preserve								// Preserve default dataframe 
	
		use "_genstacks_stkd.dta", clear nolabel	 		// First context
*		append using `appendlist', nolabel 				// This should work but yields "invalid '_genstacks3.dta''"
										//  so we do it the (slower) hard way
		local count = 1							// Start at 1 because 1st file is not appended
		foreach stackfile of local appendlist  {
			local count = `count' + 1
			append using "`stackfile'.dta", nolabel
			erase "`stackfile'.dta"
		}
		save "_genstacks_stkd.dta", replace
	
	restore									// Restore default dataframe (works this time)




					// Merge with preserved original data (constant across stacks)
													
	noisily display _newline "Merging newly stacked variables with original data, constant across stacks"

	merge 1:m _ctx_temp _respid using "_genstacks_stkd.dta", nolabel
	
	erase "_genstacks_stkd.dta"
	erase "_genstacks_orig.dta"  
	noisily display _newline "All temporary files discarded (erased)."

	drop _respid _ctx_temp _merge
	
	display _newline "Done." _newline

end
