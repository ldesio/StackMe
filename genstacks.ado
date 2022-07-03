
program drop genstacks

program define genstacks

	version 16.1											 // StackMe genstacks version 0.92, June 2022
	
	// This version of genstacks does not reshape each context separately but all contexts together. It uses external files 
	// rather than frames because of limitations on the type of merges that frames support.
	//   The program is effectively a wrapper for Stata's 'reshape' command. It's main sources of added value are 
	// (1) to skip stubs that do not have numeric suffixes (e.g. RSYML1 as a supposed variable in a battery named RSYM) and 
	// (2) to cull records that (after stacking) are all missing because stacked variables were all missing for certain 
	// contexts (especially frequent in comparative election and party studies where some countries have more parties than 
	// others and more parties at some elections than others).
	
	
	syntax namelist,  [CONtextvars(varlist)] [UNItname(name)] [STAckid(name)] [ITEmname(name)] [TOTstackname(name)] [REPlace] [NOWarnings] ///
					  [DELetemissing] [fe(namelist)] [FEPrefix(string)]
					  
	
	
	
	
								// Preprocess options with possible errors or requiring other manipulation . . .
								
	if strlen("`fe'") > 0  {
		foreach fevar of local fe  {
			if (strpos("`namelist'","`fevar'")==0) & ("`fevar'"!="_all")  {
				noisily display as error "Optioned fe var not in list of variable stubs"
				exit
			}
		}
	}

	if strlen("`replace'")>0  local r = 1
	else local r = 0
	if strlen("`nowarnings'")>0  local w = 0
	else local w = 1

	
*	gettoken firststub otherstubs: namelist				// We no longer need `firststub' as "master battery" for diagnostics
	
	// namelist contains stubs
	// var denotes a varname in the list of variables, implied by a stub*, that are to be reshaped

	set more off
	
	display in smcl _continue
	display as text
	
	
	
	
								// Diagnose batteries with different sizes or suffixes (indexes) . . .
								
	local previndexlist = ""
	local diffindexlist = 0
	local varlist = ""		

	foreach stub of local namelist {
		local indexlist = ""
		foreach var of varlist `stub'*  {
					
			// if what comes after the stub is not numeric, skip
			// this is useful if different batteries share part of the stub (e.g. rsym and rsymp)
			local strindex = substr("`var'",strlen("`stub'")+1,.)
					
			if (real("`strindex'")==.) continue			// Continue with next var if this one's suffix is not numeric
			
			local varlist = "`varlist' `var'"
			local indexlist = "`indexlist' `strindex'"

		} //next var
		if "`previndexlist'" != ""  {					// If this is 2nd or subsequent battery
			if indexnot("`indexlist'","`previndexlist'")>0  local diffindexlist = 1
			if indexnot("`previndexlist'","`indexlist'")>0  local diffindexlist = 1
		}

		} //next stub
	if `diffindexlist'>0 & `w'  display as error "WARNING: Batteries do not match across battery stubnames"
				

								
								
								
								
								// Enumerate all contexts
								
	if ("`contextvars'" == "") {
		capture drop _ctx_temp
		gen _ctx_temp = 1
		local ctxvar = "_ctx_temp"
	}
	else {
		
		capture drop _ctx_temp
		quietly _mkcross `contextvars', generate(_ctx_temp) missing
		
		local ctxvar = "_ctx_temp"
	}
	

	
	
								// Get varlist and respondent ID . . .

	sort _ctx_temp										// Sort data in order by context so _respid increases by context
	gen _respid = _n									// Not using 'bysort' since we are reshaping all contexts at once
														// Not allowing user to provide this to avoid repeats across contexts
	tempfile unstacked
	quietly save `unstacked'							// Save original dataset to merge with reshaped variables
	noisily display " "

	
	
	
								// Reshape and merge as optioned . . .
	
	quietly keep _respid _ctx_temp `varlist'			// Keep just the variables to be reshaped (and identifiers)
	
	reshape long `namelist', i(_respid) j(_genstacks_item)	// Values of '_genstacks_item' are supplied by 'reshape'

	bysort _respid:  gen _genstacks_stack = _n
	egen _genstacks_totstacks = max(_genstacks_stack), by(_respid)
	
	noisily display _newline "Merging newly stacked variables with original data, constant across stacks"

	merge m:1 _respid _ctx_temp using `unstacked', nogen nolabel
	
	
	
	
	
								// Flag and optionally drop stacks where all vars are missing . . .
								
	local totstubs = wordcount("`namelist'")
	tempvar totmiss
	egen `totmiss' = rowmiss(`namelist')

	noisily display _newline "Flagging stacked records where all reshaped variables are missing, to delete if optioned"
	tempvar dropable
	gen `dropable' = 0
	replace `dropable' = 1 if `totmiss'==`totstubs'
	
	if ("`deletemissing'"!="")  drop if `dropable'
	noisily display " "
	

	
	
	
								// label reshaped vars, based on last first var in each battery ...
									
	foreach stub of local namelist {
		foreach var of varlist `stub'*  {				// Sleight-of-hand to get first var in each battery

			local strindex = substr("`var'",strlen("`stub'")+1,.)					
			if (real("`strindex'")==.) continue			// Continue with next var if this one's suffix is not numeric

			local label : variable label `var'

			local loc = strpos("`label'","`var'")
			if (`loc'>0)  {								// Omit varname, if any, from label (it has a numeric suffix)
				local head = substr("`label'",1,`loc'-1) 
				local tail = substr("`label'",`loc'+strlen("`var'")+1,.)
				local label = "`head'`tail'"
			}
			
			display "Labeling {result:`stub'}: `label'"
			label var `stub' "`label'"
														
			continue, break								// Break out of loop now that we have the first var label
		}
	}

	if `r'  drop `varlist'								// Dropping original battery member vars was optioned
	
	sort `_respid' _genstacks_stack	


	
	

									// Process fixed effects if optioned . . .
									
	if ("`fe'"!="") {
		if ("`feprefix'"!="") {
			local feprefix = "`feprefix'"
		}
		else {
			local feprefix = "fe_"
		}
		display _newline  "{text}{pstd}Applying fixed-effects treatment (saving and subtracting the respondent-level mean){break}"
		display "to variables "
		if ("`fe'"=="_all")  local fe = "`namelist'"
		foreach fevar of local fe {
			tempvar t
			display "...`fevar' " _continue
			capture drop `feprefix'`fevar'
			bysort _respid: egen `t' = mean(`fevar')
			gen `feprefix'`fevar' = `fevar' - `t'
			drop `t'
		}
		
		display _newline
		
	} //endif ("`fe...")
	

	
									// Move stacking and stacked vars to end of dataset . . .
	
	quietly gen _genstacks = .
	
	order `namelist' _respid _genstacks_item _genstacks_stack _genstacks_totstacks ///
	      , after(_genstacks)
	
	if ("`fe'"!="")  order  fe_*, after(_genstacks_totstacks)


	
		  
		  
									// Rename generated variables if optioned . . .
									
	if ("`unitname'" != "")  rename _respid `unitname'
	else 					 rename _respid _genstacks_unit
	
	if ("`itemname'" != "")  rename _genstacks_item `itemname'
	
	if ("`stackid'" != "")   rename _genstacks_stack `stackid'
	
	if "`totstackname'" != ""  rename _genstacks_totstacks = `totstackname'

	
	
	
	
	
	
									// Finish up . . .
	
	drop _ctx_temp _genstacks
	
									// NOT DONE IN THIS VERSION ...
									// No check for duplicate stubnames because we drop vars that were reshaped, not stubs & suffixes
									// Stata's 'reshape' handles stubnames that duplicate existing variables
								
	
	noisily display "Done." _newline
	

end

